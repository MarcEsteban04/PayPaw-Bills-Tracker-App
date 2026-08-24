import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'bill.dart';
import 'bill_status.dart';

/// A bill together with what the database worked out about it.
///
/// One row of `bill_status`. **Composes** a [Bill] rather than adding fields to
/// it, so the line between stored and derived stays visible at every call site:
/// `item.bill.name` is a fact the user typed, `item.status` is a conclusion the
/// database reached. Flattening the two would put [Bill] one careless `copyWith`
/// away from carrying a status somebody could write.
///
/// Everything here except [bill] is derived, and none of it is writable.
@immutable
class BillWithStatus {
  const BillWithStatus({
    required this.bill,
    required this.status,
    required this.paid,
    required this.outstanding,
    required this.today,
    this.lastPaidAt,
  });

  final Bill bill;

  /// Null when the view returned a status this build does not recognise.
  ///
  /// Nullable on purpose: a status added to the view should surface as "unknown"
  /// on a screen the user was only reading, not as a crash. See
  /// [BillStatus.tryParse].
  final BillStatus? status;

  /// Total recorded against this bill.
  final Money paid;

  /// What is still owed. Never negative — the view clamps it, so an overpayment
  /// reads as settled rather than as a debt owed back.
  final Money outstanding;

  /// When the most recent payment was recorded, or null if there is none.
  final DateTime? lastPaidAt;

  /// The date **in the user's own time zone**, as the view computed it.
  ///
  /// Carried on every row so the UI can say "due tomorrow" without consulting the
  /// device clock. A phone in a different zone, or with the wrong date set, would
  /// otherwise disagree with the status the same row is showing — and the two
  /// contradicting each other is worse than either being wrong alone.
  final DateTime today;

  /// The bill's id. Forwarded because list keys and lookups need it constantly;
  /// everything else is reached through [bill], which is the point.
  String get id => bill.id;

  /// Whether anything has been paid without settling it.
  bool get isPartiallyPaid => paid.minorUnits > 0 && outstanding.minorUnits > 0;

  /// Days until due, counted in the user's zone. Negative when overdue.
  ///
  /// Both sides are dates at midnight, so this is a whole number of days and not
  /// a duration that rounds.
  int get daysUntilDue => DateTime(
    bill.dueOn.year,
    bill.dueOn.month,
    bill.dueOn.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;

  @override
  bool operator ==(Object other) =>
      other is BillWithStatus &&
      other.bill == bill &&
      other.status == status &&
      other.paid == paid &&
      other.outstanding == outstanding &&
      other.lastPaidAt == lastPaidAt &&
      other.today == today;

  @override
  int get hashCode =>
      Object.hash(bill, status, paid, outstanding, lastPaidAt, today);

  @override
  String toString() =>
      'BillWithStatus(${bill.name}, ${status?.wireValue ?? 'unknown'}, '
      'outstanding $outstanding)';
}
