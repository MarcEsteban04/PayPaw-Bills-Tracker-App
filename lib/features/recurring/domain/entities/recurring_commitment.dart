import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'recurrence.dart';
import 'recurrence_frequency.dart';
import 'recurring_bill.dart';

/// What the repeating bills cost, normalised to one month.
///
/// ## Why a normalised figure at all
///
/// A schedule list answers "what repeats". It does not answer the question people
/// actually have, which is **"what is this costing me a month"** — and that answer
/// is not in any single row: ₱4,000 rent, ₱1,500 internet and a ₱6,000 yearly
/// insurance are three different units, and adding them gives a number that means
/// nothing.
///
/// ## The arithmetic, and what it is not
///
/// Every rule is converted to occurrences per year, then divided by twelve. A
/// weekly bill is 365.25 / 7 weeks a year rather than 52 — the shortcut loses a
/// week every five years, which on a weekly commitment is a real amount.
///
/// **This is an average, not a forecast.** A yearly bill does not arrive in
/// twelfths, and the month it lands in is the month it hurts. The months chart on
/// the dashboard answers *when*; this answers *how much, on average* — and the two
/// are shown apart because a reader who confuses them budgets wrongly in exactly
/// one direction.
@immutable
class RecurringCommitment {
  const RecurringCommitment({
    required this.perMonth,
    required this.perYear,
    required this.activeCount,
    required this.largest,
  });

  factory RecurringCommitment.of(List<RecurringBill> templates) {
    final String currency = templates.isEmpty
        ? 'PHP'
        : templates.first.amount.currency;
    double yearlyMinorUnits = 0;
    int counted = 0;
    RecurringBill? largest;
    double largestYearly = 0;

    for (final RecurringBill template in templates) {
      // Paused and finished templates are not commitments. A schedule the user
      // stopped is not money they have to find, and counting it would inflate
      // the figure they budget against.
      if (!template.isActive || template.isFinished) {
        continue;
      }

      final double yearly = _perYear(template.recurrence, template.amount);
      if (yearly <= 0) {
        continue;
      }

      yearlyMinorUnits += yearly;
      counted++;

      if (yearly > largestYearly) {
        largestYearly = yearly;
        largest = template;
      }
    }

    return RecurringCommitment(
      // Rounded once, at the end. Rounding each template first and summing would
      // drift by up to half a centavo per bill, which shows as a total that does
      // not match its own parts.
      perMonth: Money(
        minorUnits: (yearlyMinorUnits / 12).round(),
        currency: currency,
      ),
      perYear: Money(minorUnits: yearlyMinorUnits.round(), currency: currency),
      activeCount: counted,
      largest: largest,
    );
  }

  /// The average month.
  final Money perMonth;

  /// The same commitment over twelve months, which is the honest way to show a
  /// yearly bill that has been divided into twelfths.
  final Money perYear;

  /// How many templates are contributing.
  final int activeCount;

  /// The single biggest contributor, or null when nothing repeats. Named rather
  /// than left implicit, because "what is the big one" is the next question after
  /// "how much".
  final RecurringBill? largest;

  bool get hasAnything => activeCount > 0 && perMonth.minorUnits > 0;

  /// What one template costs in an average month.
  ///
  /// The same arithmetic the total uses, exposed because a *list* of repeating
  /// obligations needs it per row: "₱549" against "₱1,200" tells the reader
  /// nothing when the first is monthly and the second is yearly, and a reader
  /// deciding what to cancel is comparing exactly those two numbers.
  ///
  /// Shares [_perYear] rather than repeating it. A second definition of what
  /// "a month" means for a quarterly bill is a second definition that can
  /// disagree, and the one that disagrees is always the one on screen.
  static Money monthlyCostOf(RecurringBill template) => Money(
    minorUnits: (_perYear(template.recurrence, template.amount) / 12).round(),
    currency: template.amount.currency,
  );

  /// What one template costs over twelve months.
  static Money yearlyCostOf(RecurringBill template) => Money(
    minorUnits: _perYear(template.recurrence, template.amount).round(),
    currency: template.amount.currency,
  );

  /// What one template costs a year, in minor units.
  ///
  /// A double rather than [Money]: this is an intermediate, and forcing it to
  /// whole centavos here is what makes twelve monthly bills fail to add up to
  /// their own yearly figure.
  static double _perYear(Recurrence rule, Money amount) {
    if (rule.intervalCount < 1) {
      return 0;
    }

    final double occurrences = switch (rule.frequency) {
      // 365.25 days a year, not 52 weeks. The shortcut loses a week every five
      // years, and on something charged weekly that is a real amount.
      RecurrenceFrequency.weekly => 365.25 / (7 * rule.intervalCount),
      RecurrenceFrequency.monthly => 12 / rule.intervalCount,
      RecurrenceFrequency.quarterly => 4 / rule.intervalCount,
      RecurrenceFrequency.yearly => 1 / rule.intervalCount,
    };

    return amount.minorUnits * occurrences;
  }
}
