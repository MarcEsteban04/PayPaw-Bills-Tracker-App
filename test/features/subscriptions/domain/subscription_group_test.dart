import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_group.dart';
import 'package:paypaw/features/subscriptions/presentation/widgets/subscription_mark.dart';

/// How the list is divided, and how each row is marked.
void main() {
  final DateTime today = DateTime(2026, 9, 3);

  Subscription subscription({
    required String provider,
    bool isActive = true,
    DateTime? trialEndsOn,
  }) => Subscription(
    template: RecurringBill(
      id: provider,
      userId: 'user-1',
      kind: RecurringBillKind.subscription,
      name: provider,
      amount: const Money.php(54900),
      recurrence: Recurrence(
        frequency: RecurrenceFrequency.monthly,
        startsOn: DateTime(2026, 1, 18),
        dayOfMonth: 18,
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

  group('grouping', () {
    test('puts trials first, then active, then stopped', () {
      // Trials lead because they are the only rows with a deadline. Everything
      // else on this screen can be dealt with next month.
      final List<SubscriptionSection> sections = groupSubscriptions(
        <Subscription>[
          subscription(provider: 'Netflix'),
          subscription(provider: 'Disney+', isActive: false),
          subscription(
            provider: 'Apple TV+',
            trialEndsOn: DateTime(2026, 9, 20),
          ),
        ],
        today: today,
      );

      expect(
        sections.map((SubscriptionSection s) => s.group),
        <SubscriptionGroup>[
          SubscriptionGroup.trial,
          SubscriptionGroup.active,
          SubscriptionGroup.stopped,
        ],
      );
    });

    test('keeps the order it was given inside each group', () {
      // The sort still decides which row is first; the group only decides which
      // heading it sits under.
      final List<SubscriptionSection> sections = groupSubscriptions(
        <Subscription>[
          subscription(provider: 'B'),
          subscription(provider: 'A'),
        ],
        today: today,
      );

      expect(
        sections.single.subscriptions.map(
          (Subscription s) => s.details.provider,
        ),
        <String>['B', 'A'],
      );
    });

    test('leaves out the groups nobody is in', () {
      // One section means no headings on screen — a heading reading "Active"
      // above every row a user has labels nothing.
      final List<SubscriptionSection> sections = groupSubscriptions(
        <Subscription>[subscription(provider: 'Netflix')],
        today: today,
      );

      expect(sections, hasLength(1));
      expect(sections.single.group, SubscriptionGroup.active);
    });

    test('a paused subscription with a live trial date is stopped', () {
      // Nothing is going to charge, so it does not belong under a heading about
      // free periods that are about to end.
      final List<SubscriptionSection> sections = groupSubscriptions(
        <Subscription>[
          subscription(
            provider: 'Apple TV+',
            isActive: false,
            trialEndsOn: DateTime(2026, 9, 20),
          ),
        ],
        today: today,
      );

      expect(sections.single.group, SubscriptionGroup.stopped);
    });

    test('nothing in, nothing out', () {
      expect(groupSubscriptions(const <Subscription>[], today: today), isEmpty);
    });
  });

  group('the provider mark', () {
    test('gives the same service the same colour every time', () {
      // The whole point. A palette that shuffled between releases would be
      // worse than no colour at all — people learn a list by its shape.
      expect(
        SubscriptionMarks.colorFor('Netflix'),
        SubscriptionMarks.colorFor('Netflix'),
      );
      expect(
        SubscriptionMarks.colorFor('netflix  '),
        SubscriptionMarks.colorFor('Netflix'),
      );
    });

    test('and stays inside the curated palette', () {
      for (final String provider in <String>[
        'Netflix',
        'Spotify',
        'Adobe',
        'Apple TV+',
        '',
        '🎬',
      ]) {
        expect(
          SubscriptionMarks.palette,
          contains(SubscriptionMarks.colorFor(provider)),
        );
      }
    });

    test('takes a letter from each of the first two words', () {
      expect(SubscriptionMarks.initialsFor('Netflix'), 'N');
      expect(SubscriptionMarks.initialsFor('Apple TV+'), 'AT');
      // Punctuation is dropped rather than rendered, so this is not "D+".
      expect(SubscriptionMarks.initialsFor('Disney+'), 'D');
      expect(SubscriptionMarks.initialsFor('  amazon prime video '), 'AP');
    });

    test('falls back rather than rendering an empty square', () {
      expect(SubscriptionMarks.initialsFor('+++'), '•');
      expect(SubscriptionMarks.initialsFor(''), '•');
    });
  });
}
