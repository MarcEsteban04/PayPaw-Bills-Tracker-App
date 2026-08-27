import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'debt.dart';
import 'debt_direction.dart';

/// A debt and what has been repaid against it.
///
/// **Composes** a [Debt] rather than flattening it, the way `BillWithStatus`
/// composes a `Bill`: `debt.principal` is a stored fact and [outstanding] is a
/// sum over `payments`, and keeping the line visible is what stops a later
/// `copyWith` writing a derived figure back.
///
/// Read from the `debt_status` view, which computes the totals in one query.
@immutable
class DebtWithStatus {
  const DebtWithStatus({
    required this.debt,
    required this.repaid,
    required this.outstanding,
    required this.paymentCount,
    required this.isFullyRepaid,
    required this.today,
    this.lastPaidAt,
  });

  final Debt debt;

  /// What has been paid back so far.
  final Money repaid;

  /// What is left, never below zero.
  ///
  /// An overpayment is a real thing — somebody hands over a round number and
  /// waves off the change — and the view clamps it, because "-₱50 left" is not
  /// a sentence anybody can act on.
  final Money outstanding;

  /// How many repayments have been made.
  ///
  /// The **instalment count**, in the sense the roadmap means it: this schema
  /// has no separate instalment plan, and a debt paid in chunks *is* a debt with
  /// several payments against it. See the sprint entry.
  final int paymentCount;

  /// Whether the payments now sum to the principal.
  ///
  /// **Distinct from [Debt.isSettled]**, and the two can disagree in both
  /// directions. Utang is not arithmetic: the last hundred pesos might be waved
  /// off, or the rest forgiven, or settled with a favour — so the numbers being
  /// square does not close a debt, and a debt being closed does not mean the
  /// numbers are.
  final bool isFullyRepaid;

  /// Today in the owner's own zone, from the database. Carried so nothing has to
  /// ask the device clock and disagree with the row beside it.
  final DateTime today;

  /// When the most recent repayment landed, or null if none has.
  final DateTime? lastPaidAt;

  String get id => debt.id;
  DebtDirection get direction => debt.direction;
  String get counterpartyName => debt.counterpartyName;
  Money get principal => debt.principal;

  /// Whether money is still expected to move.
  bool get isOpen => debt.isOpen;

  /// Whether the agreed date has passed with this still open.
  bool get isOverdue => debt.isOverdue(today);

  /// Whether a repayment date was ever agreed.
  ///
  /// Forwarded because a debt with no date can be neither overdue nor upcoming,
  /// so anything summarising those two states has to be able to ask.
  bool get hasDueDate => debt.hasDueDate;

  /// Whether some but not all of it has been repaid.
  bool get isPartiallyRepaid => repaid.minorUnits > 0 && !isFullyRepaid;

  /// How much of it is done, from 0 to 1.
  ///
  /// Clamped at 1 so an overpayment does not render as a bar past its own end.
  /// Zero for a debt of nothing, which the validators refuse but a row written
  /// by hand could still hold.
  double get progress {
    if (principal.minorUnits <= 0) {
      return 0;
    }

    return (repaid.minorUnits / principal.minorUnits).clamp(0, 1);
  }

  /// The user's own answer, which outranks the arithmetic.
  ///
  /// A debt is finished when the two people say it is. This is what a list uses
  /// to decide whether to keep showing it.
  bool get isSettled => debt.isSettled;

  @override
  bool operator ==(Object other) =>
      other is DebtWithStatus &&
      other.debt == debt &&
      other.repaid == repaid &&
      other.outstanding == outstanding &&
      other.paymentCount == paymentCount;

  @override
  int get hashCode => Object.hash(debt, repaid, outstanding, paymentCount);

  @override
  String toString() =>
      'DebtWithStatus(${debt.counterpartyName}, $outstanding of $principal '
      'left, $paymentCount payments)';
}
