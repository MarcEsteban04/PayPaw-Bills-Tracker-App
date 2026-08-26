import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import '../../../recurring/domain/entities/recurrence_frequency.dart';
import '../../../recurring/domain/entities/recurring_commitment.dart';
import 'subscription.dart';

/// What the subscriptions cost, and which ones cost the most.
///
/// ## The arithmetic is not new
///
/// `RecurringCommitment` has normalised repeating obligations to a common unit
/// since Sprint 39 — weekly on 365.25 days rather than 52 weeks, everything
/// converted to occurrences per year and divided by twelve. A subscription *is*
/// a recurring bill, so this hands it the subscription templates and keeps its
/// answer. Writing the sum again here would be a second definition of what "a
/// month" means for a quarterly plan, and the one that disagrees is always the
/// one on screen.
///
/// What is genuinely this type's own is the **scope** — subscriptions rather
/// than every schedule, so the figure is not a slice of somebody's rent — the
/// **ranking**, and the trial rule below.
///
/// ## Trials are counted apart, not counted in
///
/// A subscription still inside its free period is charging **nothing**, so
/// folding it into the monthly figure would overstate what is actually leaving
/// the account. Leaving it out silently would be worse the other way: the total
/// would jump the week it converts with nothing on screen having explained why.
///
/// So it is excluded from [perMonth] and reported as [whenTrialsConvert]. That
/// is the number somebody deciding whether to keep a trial actually wants.
///
/// **This is an average, not a forecast** — the caveat `RecurringCommitment`
/// carries and this inherits. A yearly plan does not arrive in twelfths, and the
/// month it lands in is the month it hurts.
@immutable
class SubscriptionSpend {
  const SubscriptionSpend({
    required this.perMonth,
    required this.perYear,
    required this.activeCount,
    required this.ranked,
    required this.whenTrialsConvert,
    required this.trialCount,
  });

  /// Works out the spend for [subscriptions] as of [today].
  factory SubscriptionSpend.of(
    List<Subscription> subscriptions, {
    required DateTime today,
  }) {
    final List<Subscription> charging = <Subscription>[];
    final List<Subscription> trialling = <Subscription>[];

    for (final Subscription subscription in subscriptions) {
      // Paused and finished ones are skipped by `RecurringCommitment` too. A
      // subscription somebody stopped is history, not money they have to find.
      if (!subscription.isActive) {
        continue;
      }

      if (subscription.isInTrial(today)) {
        trialling.add(subscription);
      } else {
        charging.add(subscription);
      }
    }

    final RecurringCommitment committed = RecurringCommitment.of(
      charging.map((Subscription each) => each.template).toList(),
    );
    final RecurringCommitment pending = RecurringCommitment.of(
      trialling.map((Subscription each) => each.template).toList(),
    );

    // Trials are ranked alongside the rest. Somebody asking "what is the
    // expensive one" means the commitment, whether or not it has started
    // charging yet — and a trial at the top of that list is precisely the one to
    // decide about before it converts.
    final List<Subscription> ranked = <Subscription>[...charging, ...trialling]
      ..sort(
        (Subscription a, Subscription b) =>
            monthlyCostOf(b).compareTo(monthlyCostOf(a)),
      );

    return SubscriptionSpend(
      perMonth: committed.perMonth,
      perYear: committed.perYear,
      activeCount: charging.length,
      ranked: List<Subscription>.unmodifiable(ranked),
      whenTrialsConvert: pending.perMonth,
      trialCount: trialling.length,
    );
  }

  /// What the subscriptions already charging cost in an average month.
  final Money perMonth;

  /// The same commitment over twelve months.
  ///
  /// Shown beside the monthly figure rather than instead of it, because the
  /// annual number is the one that changes minds — "₱549 a month" and "₱6,588 a
  /// year" are the same fact and only one of them sounds like a decision.
  final Money perYear;

  /// How many are charging. Excludes trials, which is what [perMonth] excludes.
  final int activeCount;

  /// Every live subscription, dearest first by monthly cost.
  ///
  /// Ranked here rather than in a widget: "most expensive" is a fact about the
  /// data, and a list sorted in the presentation layer is a list the tests
  /// cannot reach.
  final List<Subscription> ranked;

  /// What will be added to [perMonth] once the free periods end.
  final Money whenTrialsConvert;

  /// How many are still free.
  final int trialCount;

  /// The dearest, or null when nothing is live.
  Subscription? get costliest => ranked.firstOrNull;

  /// Whether there is any commitment to talk about.
  bool get hasAnything => activeCount > 0 || trialCount > 0;

  /// Whether a trial is due to start costing money.
  bool get hasPendingTrials =>
      trialCount > 0 && whenTrialsConvert.minorUnits > 0;

  /// What one subscription costs in an average month.
  ///
  /// Through the same helper the total uses — see [RecurringCommitment].
  static Money monthlyCostOf(Subscription subscription) =>
      RecurringCommitment.monthlyCostOf(subscription.template);

  /// What one subscription costs over twelve months.
  static Money yearlyCostOf(Subscription subscription) =>
      RecurringCommitment.yearlyCostOf(subscription.template);

  /// Whether [subscription] is charged at some rhythm other than monthly.
  ///
  /// The rows that need their monthly equivalent spelled out: a yearly plan's
  /// own figure is not comparable with a monthly one, and the list exists to
  /// make them comparable.
  static bool isMonthly(Subscription subscription) =>
      subscription.recurrence.frequency == RecurrenceFrequency.monthly &&
      subscription.recurrence.intervalCount == 1;

  @override
  String toString() =>
      'SubscriptionSpend($perMonth/mo, $activeCount active, '
      '$trialCount trialling)';
}
