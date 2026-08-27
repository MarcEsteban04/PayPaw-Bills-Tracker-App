import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'debt_direction.dart';
import 'debt_with_status.dart';

/// Where somebody stands on utang, both directions at once.
///
/// ## Why there is no net figure
///
/// "You are ₱800 down overall" is one number and it would fit beautifully on a
/// card, and it is the one thing this deliberately does not compute.
///
/// Subtracting what you are owed from what you owe treats a receivable as cash.
/// It is not: money lent to a cousin is not money in a wallet, half of informal
/// lending is repaid late or in kind or not at all, and a dashboard that nets
/// the two encourages spending against the optimistic half. The two sides are
/// shown **beside** each other, never folded together, and the reader does the
/// only subtraction that means anything — which is the one they choose to trust.
///
/// ## Undated debts are counted, because otherwise they vanish
///
/// A debt nobody agreed a date for can never be overdue and never be upcoming.
/// A dashboard built only from those two states would silently omit it — the
/// figure would include it and no list would — so [undatedCount] exists to say
/// so out loud.
@immutable
class DebtSummary {
  const DebtSummary({
    required this.owed,
    required this.receivable,
    required this.owedCount,
    required this.receivableCount,
    required this.overdueOwed,
    required this.overdueReceivable,
    required this.overdueCount,
    required this.undatedCount,
    required this.soonest,
  });

  /// Works out where things stand as of each row's own `today`.
  ///
  /// No date is passed in: every [DebtWithStatus] already carries the date its
  /// own status was computed against, in the owner's zone, from the view. Taking
  /// a second opinion from the device clock is how a card comes to disagree with
  /// the row it summarises.
  factory DebtSummary.of(List<DebtWithStatus> debts) {
    int owed = 0;
    int receivable = 0;
    int owedCount = 0;
    int receivableCount = 0;
    int overdueOwed = 0;
    int overdueReceivable = 0;
    int overdueCount = 0;
    int undatedCount = 0;
    DebtWithStatus? soonest;
    String currency = 'PHP';

    for (final DebtWithStatus each in debts) {
      // Settled debts are history. Counting them would inflate every figure on
      // the card with money that has stopped moving — the same rule the monthly
      // subscription commitment applies to a paused plan.
      if (!each.isOpen) {
        continue;
      }

      currency = each.outstanding.currency;
      final int left = each.outstanding.minorUnits;

      switch (each.direction) {
        case DebtDirection.iOwe:
          owed += left;
          owedCount++;
        case DebtDirection.owedToMe:
          receivable += left;
          receivableCount++;
      }

      if (each.isOverdue) {
        overdueCount++;

        switch (each.direction) {
          case DebtDirection.iOwe:
            overdueOwed += left;
          case DebtDirection.owedToMe:
            overdueReceivable += left;
        }
      } else if (!each.hasDueDate) {
        undatedCount++;
      }

      // The soonest thing with a date on it, overdue or not.
      //
      // Overdue rows are eligible on purpose: "what is next" for somebody who is
      // already late is the thing they are already late for, and skipping it to
      // name a future date would be the card looking past the problem.
      if (each.hasDueDate) {
        final DateTime due = each.debt.dueOn!;

        if (soonest == null || due.isBefore(soonest.debt.dueOn!)) {
          soonest = each;
        }
      }
    }

    return DebtSummary(
      owed: Money(minorUnits: owed, currency: currency),
      receivable: Money(minorUnits: receivable, currency: currency),
      owedCount: owedCount,
      receivableCount: receivableCount,
      overdueOwed: Money(minorUnits: overdueOwed, currency: currency),
      overdueReceivable: Money(
        minorUnits: overdueReceivable,
        currency: currency,
      ),
      overdueCount: overdueCount,
      undatedCount: undatedCount,
      soonest: soonest,
    );
  }

  /// What is still to pay out, across open debts.
  final Money owed;

  /// What is still to come back in.
  final Money receivable;

  final int owedCount;
  final int receivableCount;

  /// The late half of each side.
  final Money overdueOwed;
  final Money overdueReceivable;

  /// How many debts are past their agreed date, both directions.
  final int overdueCount;

  /// How many open debts have no agreed date at all. See the note above.
  final int undatedCount;

  /// The open debt with the earliest agreed date, or null when none has one.
  final DebtWithStatus? soonest;

  /// Whether there is any open utang at all.
  bool get hasAnything => owedCount > 0 || receivableCount > 0;

  bool get hasOverdue => overdueCount > 0;

  /// How many open debts there are, both directions.
  int get openCount => owedCount + receivableCount;

  @override
  String toString() =>
      'DebtSummary(owed $owed of $owedCount, receivable $receivable of '
      '$receivableCount, $overdueCount overdue, $undatedCount undated)';
}
