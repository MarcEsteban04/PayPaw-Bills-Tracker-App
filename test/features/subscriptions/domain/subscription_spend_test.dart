import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_spend.dart';

/// What the subscriptions cost.
///
/// The arithmetic itself belongs to `RecurringCommitment` and is tested there.
/// What is tested here is everything this type adds: the **scope**, the
/// **ranking**, and the rule that a free trial is counted apart rather than
/// counted in.
void main() {
  final DateTime today = DateTime(2026, 9, 3);

  Subscription subscription({
    required String provider,
    required int amountMinor,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int intervalCount = 1,
    bool isActive = true,
    DateTime? trialEndsOn,
  }) => Subscription(
    template: RecurringBill(
      id: provider,
      userId: 'user-1',
      kind: RecurringBillKind.subscription,
      name: provider,
      amount: Money.php(amountMinor),
      recurrence: Recurrence(
        frequency: frequency,
        startsOn: DateTime(2026, 1, 18),
        intervalCount: intervalCount,
        dayOfMonth: frequency == RecurrenceFrequency.weekly ? null : 18,
        weekday: frequency == RecurrenceFrequency.weekly ? 5 : null,
        monthOfYear: frequency == RecurrenceFrequency.yearly ? 1 : null,
      ),
      nextDueOn: DateTime(2026, 9, 18),
      isActive: isActive,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ),
    details: SubscriptionDetails(
      recurringBillId: provider,
      provider: provider,
      trialEndsOn: trialEndsOn,
    ),
  );

  group('the monthly figure', () {
    test('adds up what is actually charging', () {
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(provider: 'Netflix', amountMinor: 54900),
        subscription(provider: 'Spotify', amountMinor: 19900),
      ], today: today);

      expect(spend.perMonth, const Money.php(74800));
      expect(spend.activeCount, 2);
    });

    test('normalises a yearly plan rather than adding its face value', () {
      // ₱1,200 a year is ₱100 a month. Adding the ₱1,200 as though it were
      // monthly would overstate the commitment twelvefold — which is the whole
      // reason the figure is computed rather than summed.
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(
          provider: 'Domain',
          amountMinor: 120000,
          frequency: RecurrenceFrequency.yearly,
        ),
      ], today: today);

      expect(spend.perMonth, const Money.php(10000));
      expect(spend.perYear, const Money.php(120000));
    });

    test('leaves out a stopped subscription', () {
      // It is history, not money the user has to find. It stays on the list and
      // out of the total, which is why the card prints the count beside it.
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(provider: 'Netflix', amountMinor: 54900),
        subscription(provider: 'Disney+', amountMinor: 39900, isActive: false),
      ], today: today);

      expect(spend.perMonth, const Money.php(54900));
      expect(spend.activeCount, 1);
    });
  });

  group('a running trial', () {
    test('is not in the monthly figure, because it charges nothing', () {
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(provider: 'Netflix', amountMinor: 54900),
        subscription(
          provider: 'Apple TV+',
          amountMinor: 24900,
          trialEndsOn: DateTime(2026, 9, 20),
        ),
      ], today: today);

      expect(spend.perMonth, const Money.php(54900));
      expect(spend.activeCount, 1);
    });

    test('is reported as what the total will become', () {
      // Silence here would be worse than counting it: the total would jump the
      // week it converts with nothing on screen having explained why.
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(
          provider: 'Apple TV+',
          amountMinor: 24900,
          trialEndsOn: DateTime(2026, 9, 20),
        ),
      ], today: today);

      expect(spend.whenTrialsConvert, const Money.php(24900));
      expect(spend.trialCount, 1);
      expect(spend.hasPendingTrials, isTrue);
    });

    test('counts as charging once its last day has passed', () {
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(
          provider: 'Apple TV+',
          amountMinor: 24900,
          trialEndsOn: DateTime(2026, 8, 30),
        ),
      ], today: today);

      expect(spend.perMonth, const Money.php(24900));
      expect(spend.trialCount, 0);
    });

    test('is still free on its own last day', () {
      // A trial ending on the 3rd is free *on* the 3rd, which is how every
      // provider words it and how the user will read it.
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(
          provider: 'Apple TV+',
          amountMinor: 24900,
          trialEndsOn: today,
        ),
      ], today: today);

      expect(spend.trialCount, 1);
      expect(spend.perMonth, Money.php(0));
    });
  });

  group('the ranking', () {
    test('is by monthly cost, not by the figure on the row', () {
      // ₱1,200 a year is ₱100 a month, so the ₱149 monthly plan is dearer —
      // and sorting on the raw amount would put the yearly one first and be
      // wrong. This is the case that makes "most expensive" worth computing.
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(
          provider: 'Domain',
          amountMinor: 120000,
          frequency: RecurrenceFrequency.yearly,
        ),
        subscription(provider: 'Spotify', amountMinor: 14900),
      ], today: today);

      expect(
        spend.ranked.map((Subscription each) => each.details.provider),
        <String>['Spotify', 'Domain'],
      );
      expect(spend.costliest?.details.provider, 'Spotify');
    });

    test('includes trials, which are the ones worth deciding about', () {
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(provider: 'Spotify', amountMinor: 14900),
        subscription(
          provider: 'Adobe',
          amountMinor: 299900,
          trialEndsOn: DateTime(2026, 9, 20),
        ),
      ], today: today);

      expect(spend.costliest?.details.provider, 'Adobe');
    });

    test('leaves out what has been stopped', () {
      final SubscriptionSpend spend = SubscriptionSpend.of(<Subscription>[
        subscription(provider: 'Spotify', amountMinor: 14900),
        subscription(provider: 'Adobe', amountMinor: 299900, isActive: false),
      ], today: today);

      expect(spend.ranked.length, 1);
      expect(spend.costliest?.details.provider, 'Spotify');
    });
  });

  group('isMonthly', () {
    test('is true only for a plain every-month plan', () {
      expect(
        SubscriptionSpend.isMonthly(
          subscription(provider: 'Netflix', amountMinor: 54900),
        ),
        isTrue,
      );
      // Every two months is not monthly, and its row needs the equivalent
      // spelling out just as much as a yearly one does.
      expect(
        SubscriptionSpend.isMonthly(
          subscription(provider: 'Odd', amountMinor: 54900, intervalCount: 2),
        ),
        isFalse,
      );
      expect(
        SubscriptionSpend.isMonthly(
          subscription(
            provider: 'Domain',
            amountMinor: 120000,
            frequency: RecurrenceFrequency.yearly,
          ),
        ),
        isFalse,
      );
    });
  });

  test('nothing at all is nothing to show', () {
    final SubscriptionSpend spend = SubscriptionSpend.of(
      const <Subscription>[],
      today: today,
    );

    expect(spend.hasAnything, isFalse);
    expect(spend.costliest, isNull);
  });
}
