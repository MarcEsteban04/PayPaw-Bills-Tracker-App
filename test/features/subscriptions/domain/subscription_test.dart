import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';

/// A subscription: a recurring bill plus what makes it a subscription.
///
/// The roadmap asked Sprint 48 for a name, an amount, a billing frequency and a
/// next billing date. All four already lived on `RecurringBill`, so what is
/// tested here is the half that did not exist — the trial, the renewal, and the
/// joining of the two.
void main() {
  RecurringBill template({
    String id = 'sub-1',
    String name = 'Netflix',
    RecurringBillKind kind = RecurringBillKind.subscription,
    bool isActive = true,
    DateTime? endsOn,
  }) => RecurringBill(
    id: id,
    userId: 'user-1',
    kind: kind,
    name: name,
    amount: const Money.php(54900),
    recurrence: Recurrence(
      frequency: RecurrenceFrequency.monthly,
      startsOn: DateTime(2026, 1, 18),
      dayOfMonth: 18,
      endsOn: endsOn,
    ),
    nextDueOn: DateTime(2026, 9, 18),
    isActive: isActive,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  SubscriptionDetails details({
    String provider = 'Netflix',
    String? planName,
    DateTime? trialEndsOn,
    bool autoRenews = true,
    String? cancellationUrl,
  }) => SubscriptionDetails(
    recurringBillId: 'sub-1',
    provider: provider,
    planName: planName,
    trialEndsOn: trialEndsOn,
    autoRenews: autoRenews,
    cancellationUrl: cancellationUrl,
  );

  group('the trial', () {
    final DateTime today = DateTime(2026, 9, 3);

    test('is not one unless a date was recorded', () {
      expect(details().hasTrial, isFalse);
      expect(details().isInTrial(today), isFalse);
      expect(details().daysOfTrialLeft(today), isNull);
    });

    test('runs through its last day, not up to it', () {
      // A trial ending on the 3rd is free *on* the 3rd, which is how every
      // provider words it and how the user will read it.
      expect(
        details(trialEndsOn: DateTime(2026, 9, 3)).isInTrial(today),
        isTrue,
      );
      expect(
        details(trialEndsOn: DateTime(2026, 9, 2)).isInTrial(today),
        isFalse,
      );
    });

    test('and counts the days left, zero on the last one', () {
      expect(
        details(trialEndsOn: DateTime(2026, 9, 10)).daysOfTrialLeft(today),
        7,
      );
      expect(
        details(trialEndsOn: DateTime(2026, 9, 3)).daysOfTrialLeft(today),
        0,
      );
    });

    test('a time of day does not change the count', () {
      // `today` comes from a row and a trial date from a `date` column, and a
      // stray clock on either would otherwise shift the answer by one.
      expect(
        details(trialEndsOn: DateTime(2026, 9, 10, 23, 59))
            .daysOfTrialLeft(DateTime(2026, 9, 3, 0, 1)),
        7,
      );
    });

    test('and one that has passed counts backwards rather than clamping', () {
      // A caller that wants "over" should ask isInTrial rather than read a sign.
      expect(
        details(trialEndsOn: DateTime(2026, 8, 30)).daysOfTrialLeft(today),
        -4,
      );
    });
  });

  group('renewing', () {
    test('needs both halves to agree', () {
      // A paused template does not renew whatever the service's setting says.
      expect(
        Subscription(template: template(), details: details()).willRenew,
        isTrue,
      );
      expect(
        Subscription(
          template: template(isActive: false),
          details: details(),
        ).willRenew,
        isFalse,
      );
      expect(
        Subscription(
          template: template(),
          details: details(autoRenews: false),
        ).willRenew,
        isFalse,
      );
    });

    test('and a finished schedule is not active, whatever the flag says', () {
      // Paused and finished are different states with the same consequence: it
      // is not money the user has to find.
      final Subscription finished = Subscription(
        template: template(endsOn: DateTime(2026, 3, 18)),
        details: details(),
      );

      expect(finished.isActive, isFalse);
      expect(finished.willRenew, isFalse);
    });
  });

  group('what it is called', () {
    test('the provider on its own when there is no plan', () {
      expect(
        Subscription(template: template(), details: details()).providerLine,
        'Netflix',
      );
    });

    test('and provider with plan when there is', () {
      expect(
        Subscription(
          template: template(),
          details: details(planName: 'Premium'),
        ).providerLine,
        'Netflix · Premium',
      );
    });

    test('a blank plan is no plan', () {
      expect(
        Subscription(
          template: template(),
          details: details(planName: '   '),
        ).providerLine,
        'Netflix',
      );
    });
  });

  group('the forwarding getters', () {
    test('read the schedule rather than copying it', () {
      // Composition, not flattening: there is one amount and it lives on the
      // template. A second copy is two tables disagreeing about what Netflix
      // costs.
      final Subscription subscription = Subscription(
        template: template(),
        details: details(),
      );

      expect(subscription.id, subscription.template.id);
      expect(subscription.name, subscription.template.name);
      expect(subscription.amount, subscription.template.amount);
      expect(subscription.nextBillingOn, subscription.template.nextDueOn);
    });
  });

  group('validation', () {
    test('demands a provider, because a plan name identifies nothing', () {
      expect(details(provider: '').validate(), isNotNull);
      expect(details(provider: '   ').validate(), isNotNull);
      expect(details().validate(), isNull);
    });

    test('and mirrors the column lengths', () {
      expect(details(provider: 'x' * 121).validate(), isNotNull);
      expect(details(provider: 'x' * 120).validate(), isNull);
      expect(details(planName: 'x' * 121).validate(), isNotNull);
    });
  });

  test('a cancellation link is only one if there is something in it', () {
    expect(details().hasCancellationLink, isFalse);
    expect(details(cancellationUrl: '  ').hasCancellationLink, isFalse);
    expect(
      details(cancellationUrl: 'https://netflix.com/cancel')
          .hasCancellationLink,
      isTrue,
    );
  });

  test('clearing a field is different from leaving it alone', () {
    final SubscriptionDetails full = details(
      planName: 'Premium',
      trialEndsOn: DateTime(2026, 9, 10),
      cancellationUrl: 'https://example.test',
    );

    expect(full.copyWith().planName, 'Premium');
    expect(full.copyWith(clearPlanName: true).planName, isNull);
    expect(full.copyWith(clearTrialEndsOn: true).trialEndsOn, isNull);
    expect(full.copyWith(clearCancellationUrl: true).cancellationUrl, isNull);
    // And clearing one leaves the others where they were.
    expect(full.copyWith(clearPlanName: true).trialEndsOn, isNotNull);
  });
}
