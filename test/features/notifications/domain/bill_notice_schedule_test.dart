import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_notice.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_channel.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';

/// Which notifications should currently be scheduled.
///
/// Every rule a notification can get wrong lives here, and every one of them is
/// invisible until the morning it fires — an alert about a bill paid last week
/// is not a bug anyone sees in review. Which is exactly why the whole thing is a
/// pure function over the current set of bills rather than a dozen event
/// handlers each remembering the rules.
void main() {
  final DateTime now = DateTime(2026, 8, 25, 10);

  // A date the id tests do not care about: they key on bill, kind and offset.
  final DateTime anyTime = DateTime(2026, 1, 2);

  BillWithStatus bill({
    String id = 'bill-1',
    String name = 'Meralco',
    DateTime? dueOn,
    BillStatus? status = BillStatus.upcoming,
    bool archived = false,
    int outstanding = 150000,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      amount: const Money.php(150000),
      dueOn: dueOn ?? DateTime(2026, 9, 10),
      archivedAt: archived ? DateTime(2026, 8, 2) : null,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(150000 - outstanding),
    outstanding: Money.php(outstanding),
    today: DateTime(2026, 8, 25),
  );

  List<BillNotice> scheduleFor(
    List<BillWithStatus> bills, {
    ReminderPreferences preferences = const ReminderPreferences(),
    DateTime? at,
  }) => BillNoticeSchedule.of(bills, preferences: preferences, now: at ?? now);

  List<BillNotice> ofKind(List<BillNotice> notices, BillNoticeKind kind) =>
      notices.where((BillNotice n) => n.kind == kind).toList();

  List<BillNotice> remindersFor(
    List<BillWithStatus> bills, {
    ReminderPreferences preferences = const ReminderPreferences(),
    DateTime? at,
  }) => ofKind(
    scheduleFor(bills, preferences: preferences, at: at),
    BillNoticeKind.reminder,
  );

  List<BillNotice> overdueFor(
    List<BillWithStatus> bills, {
    ReminderPreferences preferences = const ReminderPreferences(),
    DateTime? at,
  }) => ofKind(
    scheduleFor(bills, preferences: preferences, at: at),
    BillNoticeKind.overdue,
  );

  group('reminders: when they fire', () {
    test('one per offset, at the chosen time of day', () {
      // Defaults are {3, 1, 0} at 09:00, and the bill is due on 10 September.
      expect(
        remindersFor(<BillWithStatus>[bill()])
            .map((BillNotice n) => n.firesAt)
            .toList(),
        <DateTime>[
          DateTime(2026, 9, 7, 9),
          DateTime(2026, 9, 9, 9),
          DateTime(2026, 9, 10, 9),
        ],
      );
    });

    test('an offset of zero is the due date itself, not the day before', () {
      expect(
        remindersFor(
          <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 10))],
          preferences: const ReminderPreferences(daysBefore: <int>[0]),
        ).single.firesAt,
        DateTime(2026, 9, 10, 9),
      );
    });

    test('and an offset crossing a month boundary lands correctly', () {
      // 2 October minus eight days is 24 September, and the arithmetic has to
      // normalise the month rather than producing a -6th of October.
      expect(
        remindersFor(
          <BillWithStatus>[bill(dueOn: DateTime(2026, 10, 2))],
          preferences: const ReminderPreferences(daysBefore: <int>[8]),
        ).single.firesAt,
        DateTime(2026, 9, 24, 9),
      );
    });

    test('the chosen time of day is honoured', () {
      expect(
        remindersFor(
          <BillWithStatus>[bill()],
          preferences: const ReminderPreferences(
            daysBefore: <int>[1],
            timeOfDay: ReminderTime(hour: 18, minute: 30),
          ),
        ).single.firesAt,
        DateTime(2026, 9, 9, 18, 30),
      );
    });
  });

  group('overdue: when they fire', () {
    test('the day after, then three, a week, a fortnight', () {
      // Escalating and finite. "This is late" is true every morning until the
      // bill is paid, which makes it the one message that could be sent forever.
      expect(
        overdueFor(<BillWithStatus>[bill(dueOn: DateTime(2026, 9, 10))])
            .map((BillNotice n) => n.firesAt)
            .toList(),
        <DateTime>[
          DateTime(2026, 9, 11, 9),
          DateTime(2026, 9, 13, 9),
          DateTime(2026, 9, 17, 9),
          DateTime(2026, 9, 24, 9),
        ],
      );
    });

    test('and then it stops', () {
      // By day fourteen the user is not failing to pay because they forgot, and
      // a fifth notification would be the app insisting rather than informing.
      expect(BillNoticeSchedule.overdueDays.last, 14);
      expect(overdueFor(<BillWithStatus>[bill()]), hasLength(4));
    });

    test('nothing lands on the due date itself', () {
      // That day belongs to the reminder — "due today". An overdue alert the
      // same morning would be the app contradicting itself.
      expect(
        overdueFor(<BillWithStatus>[bill(dueOn: DateTime(2026, 9, 10))])
            .where((BillNotice n) => n.firesAt.day == 10),
        isEmpty,
      );
    });

    test('they share the reminder time of day', () {
      expect(
        overdueFor(
          <BillWithStatus>[bill()],
          preferences: const ReminderPreferences(
            timeOfDay: ReminderTime(hour: 18, minute: 30),
          ),
        ).first.firesAt,
        DateTime(2026, 9, 11, 18, 30),
      );
    });
  });

  group('overdue: not saying it too often', () {
    test('a bill entered when already late does not fire a burst', () {
      // The rule that is easiest to miss. A bill added ten days late has three
      // overdue offsets behind it; without the past filter all three would fire
      // at once, the moment it was saved. Only the fourteen-day step is ahead.
      final List<BillNotice> overdue = overdueFor(<BillWithStatus>[
        bill(dueOn: DateTime(2026, 8, 15), status: BillStatus.overdue),
      ]);

      expect(overdue, hasLength(1));
      expect(overdue.single.days, 14);
      expect(overdue.single.firesAt, DateTime(2026, 8, 29, 9));
    });

    test('and one long past every step gets nothing at all', () {
      // Two months late. It is still red and still at the top of the list; the
      // notification's job is to catch a lapse, not to nag indefinitely.
      expect(
        overdueFor(<BillWithStatus>[
          bill(dueOn: DateTime(2026, 6, 10), status: BillStatus.overdue),
        ]),
        isEmpty,
      );
    });

    test('one notice per step, never two for the same day', () {
      final List<BillNotice> overdue = overdueFor(<BillWithStatus>[bill()]);

      expect(
        overdue.map((BillNotice n) => n.firesAt).toSet(),
        hasLength(overdue.length),
      );
    });
  });

  group('what is left out', () {
    test('any reminder already in the past', () {
      // The 25th at 09:00 has gone; it is 10:00. Scheduling it would either be
      // refused or fire at once — a warning that a bill is due in three days,
      // arriving late, is worse than none.
      expect(
        remindersFor(<BillWithStatus>[
          bill(dueOn: DateTime(2026, 8, 25)),
        ], preferences: const ReminderPreferences(daysBefore: <int>[0])),
        isEmpty,
      );
    });

    test('but the same day later on still counts', () {
      expect(
        remindersFor(
          <BillWithStatus>[bill(dueOn: DateTime(2026, 8, 25))],
          preferences: const ReminderPreferences(
            daysBefore: <int>[0],
            timeOfDay: ReminderTime(hour: 18, minute: 0),
          ),
        ).single.firesAt,
        DateTime(2026, 8, 25, 18),
      );
    });

    test('a settled bill gets neither kind', () {
      // Paying a bill and then being told about it twice more is the single
      // most annoying thing a notification can do — and exactly what an
      // event-driven scheduler forgets to undo.
      expect(
        scheduleFor(<BillWithStatus>[bill(status: BillStatus.paid)]),
        isEmpty,
      );
    });

    test('nor does an archived one', () {
      expect(
        scheduleFor(<BillWithStatus>[
          bill(status: BillStatus.archived, archived: true),
        ]),
        isEmpty,
      );
    });

    test('an overdue bill gets no reminders, but does get overdue notices', () {
      // Sprint 40 dropped overdue bills entirely, which was right then: every
      // reminder for a bill already late is in the past anyway. Their overdue
      // notices are not.
      final List<BillWithStatus> late = <BillWithStatus>[
        bill(dueOn: DateTime(2026, 8, 24), status: BillStatus.overdue),
      ];

      expect(remindersFor(late), isEmpty);
      expect(overdueFor(late), isNotEmpty);
    });

    test('everything, when the user has turned notifications off', () {
      // One switch for both kinds. It reads "reminders", but it is the user
      // asking PayPaw not to notify them about bills, and honouring that for
      // the gentler message while overriding it for the blunter one would be
      // the app deciding it knows better.
      expect(
        scheduleFor(<BillWithStatus>[
          bill(),
        ], preferences: const ReminderPreferences(isEnabled: false)),
        isEmpty,
      );
    });

    test('and a partly paid bill is still owed, so it still notifies', () {
      expect(
        scheduleFor(<BillWithStatus>[
          bill(status: BillStatus.partiallyPaid, outstanding: 50000),
        ]),
        isNotEmpty,
      );
    });
  });

  group('the order they come out in', () {
    test('soonest first, whichever kind', () {
      // The two kinds interleave: one bill's overdue notices fall between
      // another's reminders, and the caller hands the whole list to a scheduler
      // that has no opinion about which is which.
      final List<BillNotice> notices = scheduleFor(<BillWithStatus>[
        bill(id: 'later', dueOn: DateTime(2026, 10, 5)),
        bill(id: 'sooner', dueOn: DateTime(2026, 9, 10)),
      ]);

      for (int i = 1; i < notices.length; i++) {
        expect(
          notices[i].firesAt.isBefore(notices[i - 1].firesAt),
          isFalse,
          reason: 'notices should be in firing order',
        );
      }
    });
  });

  group('what each one carries', () {
    test('the bill it is about, and what is still owed', () {
      // The outstanding amount, not the billed one: a bill with ₱1,000 left on
      // ₱1,500 should say ₱1,000.
      final BillNotice notice = remindersFor(<BillWithStatus>[
        bill(status: BillStatus.partiallyPaid, outstanding: 100000),
      ]).first;

      expect(notice.billId, 'bill-1');
      expect(notice.billName, 'Meralco');
      expect(notice.amount, '₱1,000.00');
      expect(notice.dueOn, DateTime(2026, 9, 10));
    });

    test('and the channel it belongs on', () {
      // The one thing that keeps "your rent is late" from being silenced by
      // someone who only wanted the courtesy reminders turned off.
      expect(
        BillNoticeKind.reminder.channel,
        NotificationChannel.billReminders,
      );
      expect(BillNoticeKind.overdue.channel, NotificationChannel.overdueBills);
    });
  });

  group('notification ids', () {
    BillNotice noticeOf(BillNoticeKind kind, int days) => BillNotice(
      kind: kind,
      billId: 'bill-1',
      billName: 'Meralco',
      days: days,
      firesAt: anyTime,
      dueOn: anyTime,
      amount: '₱1.00',
    );

    test('the two kinds do not collide at the same offset', () {
      // Without the kind in the key, a reminder three days before and an
      // overdue notice three days after the same bill would hash the same, and
      // the second would silently replace the first.
      expect(
        noticeOf(BillNoticeKind.reminder, 3).notificationId,
        isNot(noticeOf(BillNoticeKind.overdue, 3).notificationId),
      );
    });

    test('every notice in a real schedule is unique', () {
      final List<BillNotice> notices = scheduleFor(<BillWithStatus>[
        bill(id: 'a'),
        bill(id: 'b'),
      ]);

      expect(
        notices.map((BillNotice n) => n.notificationId).toSet(),
        hasLength(notices.length),
      );
    });

    test('and are always positive, which the platform requires', () {
      for (final String id in <String>['a', 'zzz', 'bill-99', '']) {
        final BillNotice notice = BillNotice(
          kind: BillNoticeKind.overdue,
          billId: id,
          billName: 'x',
          days: 3,
          firesAt: anyTime,
          dueOn: anyTime,
          amount: '₱1.00',
        );

        expect(notice.notificationId, greaterThanOrEqualTo(0));
      }
    });
  });

  group('what the notification says', () {
    BillNotice noticeOf(BillNoticeKind kind, int days) => BillNotice(
      kind: kind,
      billId: 'bill-1',
      billName: 'Rent',
      days: days,
      firesAt: anyTime,
      dueOn: DateTime(2026, 9, 10),
      amount: '₱4,000.00',
    );

    test('the bill name leads, whichever kind it is', () {
      // What the reader is scanning for among a dozen other notifications.
      // "PayPaw reminder" would tell them which app and nothing they need.
      expect(noticeOf(BillNoticeKind.reminder, 3).title, startsWith('Rent'));
      expect(noticeOf(BillNoticeKind.overdue, 3).title, startsWith('Rent'));
    });

    test('a reminder counts down in words where there are words', () {
      expect(noticeOf(BillNoticeKind.reminder, 0).title, 'Rent is due today');
      expect(
        noticeOf(BillNoticeKind.reminder, 1).title,
        'Rent is due tomorrow',
      );
      expect(
        noticeOf(BillNoticeKind.reminder, 7).title,
        'Rent is due in 7 days',
      );
    });

    test('and an overdue notice counts up, without a number on the first', () {
      // A day late is a lapse; "1 day overdue" reads like a bank statement.
      // After that the gap is what tells the reader how bad this has got.
      expect(noticeOf(BillNoticeKind.overdue, 1).title, 'Rent is overdue');
      expect(
        noticeOf(BillNoticeKind.overdue, 3).title,
        'Rent is 3 days overdue',
      );
      expect(
        noticeOf(BillNoticeKind.overdue, 14).title,
        'Rent is 14 days overdue',
      );
    });

    test('the body carries the amount, and the date in the right tense', () {
      // The two things that decide whether to act now, on a lock screen where
      // opening the app is the expensive option.
      expect(
        noticeOf(BillNoticeKind.reminder, 3).body,
        '₱4,000.00 · due Thu, Sep 10',
      );
      expect(
        noticeOf(BillNoticeKind.overdue, 3).body,
        '₱4,000.00 · was due Thu, Sep 10',
      );
    });
  });

  group('the preferences themselves', () {
    test('fire furthest-warning first, whatever order they were stored in', () {
      // The column is an array with no ordering guarantee, and nothing stops
      // {0,3,1} being written.
      expect(
        const ReminderPreferences(daysBefore: <int>[0, 3, 1]).orderedOffsets,
        <int>[3, 1, 0],
      );
    });

    test('and a duplicated offset is one reminder, not two', () {
      expect(
        const ReminderPreferences(daysBefore: <int>[3, 3, 1]).orderedOffsets,
        <int>[3, 1],
      );
    });

    test('the defaults match the column defaults', () {
      // Pinned to `0003_reminder_preferences.sql`. Two definitions of "three
      // days out" that drift is a user reminded on a day nobody chose.
      expect(ReminderPreferences.defaultDaysBefore, <int>[3, 1, 0]);
      expect(const ReminderPreferences().timeOfDay, ReminderTime.defaultValue);
      expect(const ReminderPreferences().isEnabled, isTrue);
    });

    test('and validity mirrors what the column will accept', () {
      expect(const ReminderPreferences().isValid, isTrue);
      expect(const ReminderPreferences(daysBefore: <int>[]).isValid, isFalse);
      expect(
        const ReminderPreferences(daysBefore: <int>[1, 2, 3, 4, 5, 6]).isValid,
        isFalse,
      );
      expect(const ReminderPreferences(daysBefore: <int>[-1]).isValid, isFalse);
      expect(const ReminderPreferences(daysBefore: <int>[61]).isValid, isFalse);
    });
  });

  group('per-bill overrides', () {
    Map<String, BillReminderOverride> only(BillReminderOverride override) =>
        <String, BillReminderOverride>{override.billId: override};

    /// Everything scheduled for [bills] with one bill overridden.
    List<BillNotice> withOverride(
      List<BillWithStatus> bills,
      BillReminderOverride override, {
      ReminderPreferences preferences = const ReminderPreferences(),
    }) => BillNoticeSchedule.of(
      bills,
      preferences: preferences,
      now: now,
      overrides: only(override),
    );

    /// The reminders only. An upcoming bill also carries the overdue notices it
    /// will earn if it goes unpaid, and they are not what these tests are about.
    List<DateTime> reminderTimes(
      List<BillWithStatus> bills,
      BillReminderOverride override, {
      ReminderPreferences preferences = const ReminderPreferences(),
    }) => ofKind(
      withOverride(bills, override, preferences: preferences),
      BillNoticeKind.reminder,
    ).map((BillNotice n) => n.firesAt).toList();

    test('a bill with no override follows the defaults', () {
      expect(
        reminderTimes(<BillWithStatus>[
          bill(),
        ], const BillReminderOverride(billId: 'other-bill', isEnabled: false)),
        <DateTime>[
          DateTime(2026, 9, 7, 9),
          DateTime(2026, 9, 9, 9),
          DateTime(2026, 9, 10, 9),
        ],
      );
    });

    test('silencing one bill leaves the rest alone', () {
      final List<BillNotice> notices = BillNoticeSchedule.of(
        <BillWithStatus>[bill(), bill(id: 'bill-2', name: 'Globe')],
        preferences: const ReminderPreferences(),
        now: now,
        overrides: only(
          const BillReminderOverride(billId: 'bill-1', isEnabled: false),
        ),
      );

      expect(notices.map((BillNotice n) => n.billId).toSet(), <String>{
        'bill-2',
      });
    });

    test('and silences its overdue alerts too, not just its reminders', () {
      // The switch reads as "remind me about it", and a user who turns it off
      // for a bill on auto-debit does not expect to be told it is late four
      // times anyway.
      expect(
        withOverride(<BillWithStatus>[
          bill(dueOn: DateTime(2026, 8, 24), status: BillStatus.overdue),
        ], const BillReminderOverride(billId: 'bill-1', isEnabled: false)),
        isEmpty,
      );
    });

    test('a different set of days replaces the defaults for that bill', () {
      expect(
        reminderTimes(<BillWithStatus>[
          bill(),
        ], const BillReminderOverride(billId: 'bill-1', daysBefore: <int>[7])),
        <DateTime>[DateTime(2026, 9, 3, 9)],
      );
    });

    test('a different time moves them without touching the days', () {
      expect(
        reminderTimes(
          <BillWithStatus>[bill()],
          const BillReminderOverride(
            billId: 'bill-1',
            timeOfDay: ReminderTime(hour: 18, minute: 30),
          ),
        ),
        <DateTime>[
          DateTime(2026, 9, 7, 18, 30),
          DateTime(2026, 9, 9, 18, 30),
          DateTime(2026, 9, 10, 18, 30),
        ],
      );
    });

    test('an override can bring back a bill the defaults switched off', () {
      // Inheritance is field by field, so "off for everything, on for this one"
      // has to work — otherwise the master switch is a trap for anyone who
      // wants reminders about a single bill.
      expect(
        reminderTimes(
          <BillWithStatus>[bill()],
          const BillReminderOverride(billId: 'bill-1', isEnabled: true),
          preferences: const ReminderPreferences(isEnabled: false),
        ).length,
        3,
      );
    });

    test('an override that sets nothing changes nothing', () {
      expect(
        reminderTimes(<BillWithStatus>[
          bill(),
        ], const BillReminderOverride(billId: 'bill-1')),
        remindersFor(<BillWithStatus>[bill()])
            .map((BillNotice n) => n.firesAt)
            .toList(),
      );
    });

    test('the overdue offsets are not something a bill can change', () {
      // Deliberately: {1, 3, 7, 14} and then stop is the anti-spam rule, and it
      // is stated on the settings screen rather than offered.
      expect(
        ofKind(
          withOverride(
            <BillWithStatus>[
              bill(dueOn: DateTime(2026, 8, 24), status: BillStatus.overdue),
            ],
            const BillReminderOverride(billId: 'bill-1', daysBefore: <int>[7]),
          ),
          BillNoticeKind.overdue,
        ).map((BillNotice n) => n.days).toList(),
        // Not day one: that one fired at 09:00 this morning, an hour before
        // now, and the schedule never carries a time already past.
        <int>[3, 7, 14],
      );
    });
  });
}
