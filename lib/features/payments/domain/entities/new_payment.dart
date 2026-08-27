import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'payment_method.dart';
import 'payment_target.dart';

/// A payment the user has described but the database has not yet stored.
///
/// Separate from [Payment] for the reason `NewBill` is separate from `Bill`: the
/// stored row owns its id and both timestamps, and reusing the stored type here
/// would mean inventing all three.
///
/// No `userId`. The repository fills it from the session, so a caller cannot get
/// it wrong and cannot set it to somebody else.
///
/// ## What it is paid against
///
/// The table takes a payment against a bill *or* a debt and enforces exactly one
/// of the two with a check constraint. [target] is that constraint expressed in
/// types — see [PaymentTarget] for why it is a closed type rather than the
/// nullable pair this class used to be heading towards.
@immutable
class NewPayment {
  const NewPayment({
    required this.target,
    required this.amount,
    required this.paidAt,
    this.method,
    this.reference,
    this.note,
  });

  /// Convenience for the common case, and for the call sites that predate debts.
  NewPayment.forBill({
    required String billId,
    required this.amount,
    required this.paidAt,
    this.method,
    this.reference,
    this.note,
  }) : target = PaymentTarget.bill(billId);

  /// The bill or debt this settles some of.
  final PaymentTarget target;

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
    PaymentTarget? target,
    Money? amount,
    DateTime? paidAt,
    PaymentMethod? method,
    String? reference,
    String? note,
  }) => NewPayment(
    target: target ?? this.target,
    amount: amount ?? this.amount,
    paidAt: paidAt ?? this.paidAt,
    method: method ?? this.method,
    reference: reference ?? this.reference,
    note: note ?? this.note,
  );

  @override
  bool operator ==(Object other) =>
      other is NewPayment &&
      other.target == target &&
      other.amount == amount &&
      other.paidAt == paidAt &&
      other.method == method &&
      other.reference == reference &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(target, amount, paidAt, method, reference, note);

  @override
  String toString() =>
      'NewPayment($amount against $target at ${paidAt.toIso8601String()})';
}
