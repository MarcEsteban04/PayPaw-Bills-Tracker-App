import 'package:meta/meta.dart';

/// What a payment is *against*: a bill, or a debt.
///
/// ## The decision Sprint 41 left open
///
/// `NewPayment` carried a bare `billId` and said so in its own doc: the table
/// takes a payment against a bill **or** a debt and enforces exactly one of the
/// two, and "when debts land, this either grows a target or gains a sibling".
/// Both cases are now in front of us, and neither of those two options is this
/// one — which is why this is a third.
///
/// **A nullable pair was the obvious move and the wrong one.** `String? billId,
/// String? debtId` puts a rule the database enforces — `num_nonnulls(bill_id,
/// debt_id) = 1` — into a shape the compiler cannot check. Every call site could
/// then set both, or neither, and find out from a Postgres error.
///
/// **A sibling `NewDebtPayment` was the other, and duplicates everything.**
/// Amount, date, method, reference, note and every validator over them are
/// identical; the target is the only difference. Two classes would be two places
/// to fix the next thing that changes about recording money.
///
/// So the target is its own closed type. `bill` and `debt` are the only two
/// there will ever be — the check constraint says so — and a `switch` over this
/// is exhaustive, which is the property the nullable pair threw away.
@immutable
sealed class PaymentTarget {
  const PaymentTarget();

  /// A payment against a bill.
  const factory PaymentTarget.bill(String id) = BillTarget;

  /// A payment against a debt.
  const factory PaymentTarget.debt(String id) = DebtTarget;

  /// The row this payment points at.
  String get id;
}

/// A bill being paid.
final class BillTarget extends PaymentTarget {
  const BillTarget(this.id);

  @override
  final String id;

  @override
  bool operator ==(Object other) => other is BillTarget && other.id == id;

  @override
  int get hashCode => Object.hash('bill', id);

  @override
  String toString() => 'BillTarget($id)';
}

/// A debt being repaid.
final class DebtTarget extends PaymentTarget {
  const DebtTarget(this.id);

  @override
  final String id;

  @override
  bool operator ==(Object other) => other is DebtTarget && other.id == id;

  @override
  int get hashCode => Object.hash('debt', id);

  @override
  String toString() => 'DebtTarget($id)';
}
