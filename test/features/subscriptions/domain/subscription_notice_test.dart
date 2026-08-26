import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_channel.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/scheduled_notice.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_notice.dart';

/// What PayPaw says before money leaves for a subscription.
///
/// The rule this file is mostly about is the one that says **nothing**: a
/// monthly plan's renewal is already covered by its own generated bill's
/// reminder, and a second notice for the same charge is how a channel earns
/// itself a mute.
void main() {
  final DateTime now = DateTime(2026, 9, 3, 8);

  const ReminderPreferences preferences = ReminderPreferences();

  Subscription subscription({
    String id = 'sub-1',
    String provider = 'Netflix',
    int amountMinor = 54900,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int intervalCount = 1,
    bool isActive = true,
    bool autoRenews = true,
    DateTime? trialEndsOn,
    DateTime? nextDueOn,
  }) => Subscription(
    template: RecurringBill(
      id: id,
      userId: 'user-1',
      kind: RecurringBillKind.subscription,
      name: provider,
      amount: Money.php(amountMinor),
      recurrence: Recurrence(
        frequency: frequency,
        startsOn: DateTime(2026, 1, 18),
        intervalCount: intervalCount,
        dayOfMonth: 18,
        monthOfYear: frequency == RecurrenceFrequency.yearly ? 1 : null,
      ),
      nextDueOn: nextDueOn ?? DateTime(2026, 9, 18),
      isActive: isActive,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ),
    details: SubscriptionDetails(
      recurringBillId: id,
      provider: provider,
      trialEndsOn: trialEndsOn,
      autoRenews: autoRenews,
    ),
  );

  List<SubscriptionNotice> noticesFor(
    List<Subscription> subscriptions, {
    ReminderPreferences rules = preferences,
  }) => SubscriptionNoticeSchedule.of(
    subscriptions,
    preferences: rules,
    now: now,
  );

  group('a trial about to convert', () {
    test('is warned about, because no bill exists to warn about it', () {
      // The gap this sprint is really for. `trial_ends_on` is a date on the
      // subscription row with no occurrence in `bills`, so nothing was ever
      // scheduled against it.
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(trialEndsOn: DateTime(2026, 9, 20)),
      ]);

      expect(
        notices.map((SubscriptionNotice n) => n.days),
        SubscriptionNoticeSchedule.trialDays,
      );
      expect(
        notices.every(
          (SubscriptionNotice n) =>
              n.kind == SubscriptionNoticeKind.trialEnding,
        ),
        isTrue,
      );
    });

    test('says what will happen, not what is ending', () {
      final SubscriptionNotice notice = noticesFor(<Subscription>[
        subscription(provider: 'Apple TV+', trialEndsOn: DateTime(2026, 9, 4)),
      ]).single;

      // "Your trial ends tomorrow" is a fact about a calendar. This is a fact
      // about money, and only one of them makes somebody open the app.
      expect(notice.title, 'Apple TV+ starts charging tomorrow');
      expect(notice.body, contains('cancel before then'));
      expect(notice.body, contains('₱549.00'));
    });

    test('suppresses the renewal notice, because it is one event', () {
      // A yearly plan would otherwise get both: a trial warning and a renewal
      // warning about the same first charge.
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(
          frequency: RecurrenceFrequency.yearly,
          trialEndsOn: DateTime(2026, 9, 20),
        ),
      ]);

      expect(
        notices.map((SubscriptionNotice n) => n.kind).toSet(),
        <SubscriptionNoticeKind>{SubscriptionNoticeKind.trialEnding},
      );
    });

    test('is not warned about once it has already converted', () {
      expect(
        noticesFor(<Subscription>[
          subscription(trialEndsOn: DateTime(2026, 8, 20)),
        ]),
        isEmpty,
      );
    });
  });

  group('a renewal', () {
    test('is announced for a yearly plan, which is the one that ambushes', () {
      // Eleven months since the user last thought about it, and ₱6,000 leaves
      // the account.
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(
          provider: 'Adobe',
          amountMinor: 600000,
          frequency: RecurrenceFrequency.yearly,
        ),
      ]);

      expect(
        notices.map((SubscriptionNotice n) => n.days),
        SubscriptionNoticeSchedule.renewalDays,
      );
      expect(notices.first.title, contains('Adobe renews in'));
    });

    test('is silent for a monthly plan, whose bill already reminds', () {
      // The generator materialises 45 days out and `BillNoticeSchedule` already
      // schedules against those bills, so "Netflix is due in 3 days" arrives
      // without this. Two notifications for one charge is how a channel gets
      // muted.
      expect(noticesFor(<Subscription>[subscription()]), isEmpty);
    });

    test('is silent for a weekly plan, for the same reason and more so', () {
      expect(
        noticesFor(<Subscription>[
          subscription(frequency: RecurrenceFrequency.weekly),
        ]),
        isEmpty,
      );
    });

    test('is announced for a quarterly plan', () {
      expect(
        noticesFor(<Subscription>[
          subscription(frequency: RecurrenceFrequency.quarterly),
        ]),
        isNotEmpty,
      );
    });

    test('is announced for an every-other-month plan', () {
      // Not monthly, whatever the frequency enum says. Two months is long
      // enough to forget.
      expect(
        noticesFor(<Subscription>[subscription(intervalCount: 2)]),
        isNotEmpty,
      );
    });

    test('is silent for one the user has already set not to renew', () {
      expect(
        noticesFor(<Subscription>[
          subscription(
            frequency: RecurrenceFrequency.yearly,
            autoRenews: false,
          ),
        ]),
        isEmpty,
      );
    });

    test('warns further ahead than a bill reminder does', () {
      // A bill can be paid on the day it is due. A subscription often cannot be
      // cancelled on the day it renews.
      expect(
        SubscriptionNoticeSchedule.renewalDays.first,
        greaterThan(
          preferences.daysBefore.reduce((int a, int b) => a > b ? a : b),
        ),
      );
    });
  });

  group('whatever the kind', () {
    test('a stopped subscription is silent — nothing is charging', () {
      expect(
        noticesFor(<Subscription>[
          subscription(frequency: RecurrenceFrequency.yearly, isActive: false),
        ]),
        isEmpty,
      );
    });

    test('turning reminders off turns these off too', () {
      // It reads "reminders", but it is the user asking PayPaw not to notify
      // them. Deciding this message is too important to obey that would be the
      // app knowing better.
      expect(
        noticesFor(<Subscription>[
          subscription(trialEndsOn: DateTime(2026, 9, 20)),
        ], rules: preferences.copyWith(isEnabled: false)),
        isEmpty,
      );
    });

    test('an offset already in the past is not scheduled', () {
      // Android fires an overdue schedule immediately on some versions, which
      // turns opening the app into a burst of notifications about deadlines
      // that have gone.
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(trialEndsOn: DateTime(2026, 9, 4)),
      ]);

      // Three days out was the 1st, which has passed. Only the day-before
      // survives.
      expect(notices.map((SubscriptionNotice n) => n.days), <int>[1]);
    });

    test('fires at the hour the user chose', () {
      final SubscriptionNotice notice = noticesFor(<Subscription>[
        subscription(trialEndsOn: DateTime(2026, 9, 4)),
      ]).single;

      expect(notice.firesAt, DateTime(2026, 9, 3, 9));
    });

    test('posts to its own channel, not the bill ones', () {
      final SubscriptionNotice notice = noticesFor(<Subscription>[
        subscription(trialEndsOn: DateTime(2026, 9, 4)),
      ]).single;

      expect(notice.channel, NotificationChannel.subscriptionNotices);
    });

    test('carries a payload that routes to the subscription', () {
      final SubscriptionNotice notice = noticesFor(<Subscription>[
        subscription(id: 'sub-42', trialEndsOn: DateTime(2026, 9, 4)),
      ]).single;

      expect(NoticeTarget.decode(notice.payload), (
        NoticeTargetKind.subscription,
        'sub-42',
      ));
    });

    test('ids do not collide across kinds or offsets', () {
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(id: 'a', frequency: RecurrenceFrequency.yearly),
        subscription(
          id: 'b',
          frequency: RecurrenceFrequency.yearly,
          trialEndsOn: DateTime(2026, 9, 30),
        ),
      ]);

      expect(
        notices.map((SubscriptionNotice n) => n.notificationId).toSet(),
        hasLength(notices.length),
      );
    });

    test('comes back soonest first', () {
      final List<SubscriptionNotice> notices = noticesFor(<Subscription>[
        subscription(
          id: 'later',
          frequency: RecurrenceFrequency.yearly,
          nextDueOn: DateTime(2026, 11, 18),
        ),
        subscription(id: 'sooner', trialEndsOn: DateTime(2026, 9, 30)),
      ]);

      expect(
        notices.map((SubscriptionNotice n) => n.firesAt).toList(),
        orderedEquals(
          <DateTime>[...notices.map((SubscriptionNotice n) => n.firesAt)]
            ..sort(),
        ),
      );
    });
  });

  group('the payload format', () {
    test('reads an unprefixed id as a bill', () {
      // A notification scheduled by a build that only knew about bills is
      // sitting in Android's alarm table right now, and it will fire.
      expect(NoticeTarget.decode('abc-123'), (
        NoticeTargetKind.bill,
        'abc-123',
      ));
    });

    test('round-trips both kinds', () {
      for (final NoticeTargetKind kind in NoticeTargetKind.values) {
        expect(NoticeTarget.decode(NoticeTarget.encode(kind, 'id-1')), (
          kind,
          'id-1',
        ));
      }
    });

    test('is null for nothing usable', () {
      expect(NoticeTarget.decode(null), isNull);
      expect(NoticeTarget.decode('   '), isNull);
      expect(NoticeTarget.decode('subscription:'), isNull);
    });
  });
}
