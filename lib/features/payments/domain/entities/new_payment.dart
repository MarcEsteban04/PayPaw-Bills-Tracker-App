import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'payment_method.dart';

/// A payment the user has described but the database has not yet stored.
///
/// Separate from [Payment] for the reason `NewBill` is separate from `Bill`: the
/// stored row owns its id and both timestamps, and reusing the stored type here
/// would mean inventing all three.
///
/// No `userId`. The repository fills it from the session, so a caller cannot get
/// it wrong and cannot set it to somebody else.
///
/// ## Bills only, for now
///
/// The table takes a payment against a bill *or* a debt and enforces exactly one
/// of the two. This carries only [billId], because debts arrive in Phase 11 and a
/// nullable pair with a check the compiler cannot see would be a worse contract
/// than the one the database already has. When debts land, this either grows a
/// target or gains a sibling — that decision belongs to the sprint that has both
/// cases in front of it.
@immutable
class NewPayment {
  const NewPayment({
    required this.billId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.reference,
    this.note,
  });

  final String billId;

  /// Always positive. The column refuses zero and negatives; the validators
  /// refuse them earlier, with a sentence a person can act on.
  final Money amount;

  /// When the money actually moved — a real moment, so it keeps its time of day
  /// rather than being flattened to a date the way a due date is.
  final DateTime paidAt;

  final PaymentMethod? method;

  /// The reference number from the receipt.
  final String? reference;

  final String? note;

  NewPayment copyWith({
    String? billId,
    Money? amount,
    DateTime? paidAt,
    PaymentMethod? method,
    String? reference,
    String? note,
  }) => NewPayment(
    billId: billId ?? this.billId,
    amount: amount ?? this.amount,
    paidAt: paidAt ?? this.paidAt,
    method: method ?? this.method,
    reference: reference ?? this.reference,
    note: note ?? this.note,
  );

  @override
  bool operator ==(Object other) =>
      other is NewPayment &&
      other.billId == billId &&
      other.amount == amount &&
      other.paidAt == paidAt &&
      other.method == method &&
      other.reference == reference &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(billId, amount, paidAt, method, reference, note);

  @override
  String toString() =>
      'NewPayment($amount against $billId at ${paidAt.toIso8601String()})';
}
