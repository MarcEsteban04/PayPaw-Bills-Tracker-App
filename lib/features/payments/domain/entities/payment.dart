import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'payment_method.dart';

/// Money that actually moved, against a bill or a debt.
///
/// **Partial payments need no special handling.** They are simply payments that
/// sum to less than the amount due — the `bill_status` view does the summing, and
/// nothing here has to know whether a payment settled anything.
///
/// Exactly one of [billId] and [debtId] is set, enforced by a check constraint on
/// the table. Not modelled as a sealed pair of subtypes: the two cases differ in
/// nothing but which column is filled, and a hierarchy would buy type safety over
/// a distinction no caller makes.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
    this.billId,
    this.debtId,
    this.method,
    this.reference,
    this.note,
  });

  final String id;
  final String userId;

  /// The bill this paid down, when it was a bill.
  final String? billId;

  /// The debt this repaid, when it was a debt.
  final String? debtId;

  /// Always positive. The table refuses zero and negatives — a refund is not a
  /// negative payment, and modelling it as one would make every sum a guess.
  final Money amount;

  /// When the money moved. A real moment, unlike a due date, so it is a
  /// timestamptz and it is shown in the reader's own timezone.
  final DateTime paidAt;

  /// Null when the row holds a method this build does not know.
  final PaymentMethod? method;

  /// The reference number from the receipt — the thing you need when a payment is
  /// disputed, and the thing nobody can find later.
  final String? reference;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Payment && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
