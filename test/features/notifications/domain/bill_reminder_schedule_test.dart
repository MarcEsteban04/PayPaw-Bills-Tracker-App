import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';

/// Which reminders should currently be scheduled.
///
/// Every rule a reminder can get wrong lives here, and every one of them is
/// invisible until the day it fires — a notification about a bill paid last week
/// is not a bug anyone sees in review. Which is exactly why the whole thing is a
/// pure function over the current set of bills rather than a dozen event
/// handlers each remembering the rules.
void main() {
  final DateTime now = DateTime(2026, 8, 25, 10);

  // A date the id tests do not care about: they key on bill and offset only.
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

  List<BillReminder> scheduleFor(
    List<BillWithStatus> bills, {
    ReminderPreferences preferences = const ReminderPreferences(),
    DateTime? at,
  }) =>
      BillReminderSchedule.of(bills, preferences: preferences, now: at ?? now);

  group('when they fire', () {
    test('one per offset, at the chosen time of day', () {
      // Defaults are {3, 1, 0} at 09:00, and the bill is due on 10 September.
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(),
      ]);

      expect(reminders.map((BillReminder r) => r.firesAt).toList(), <DateTime>[
        DateTime(2026, 9, 7, 9),
        DateTime(2026, 9, 9, 9),
        DateTime(2026, 9, 10, 9),
      ]);
    });

    test('and they come out soonest first', () {
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(id: 'later', dueOn: DateTime(2026, 10, 5)),
        bill(id: 'sooner', dueOn: DateTime(2026, 9, 10)),
      ]);

      for (int i = 1; i < reminders.length; i++) {
        expect(
          reminders[i].firesAt.isBefore(reminders[i - 1].firesAt),
          isFalse,
          reason: 'reminders should be in firing order',
        );
      }
    });

    test('an offset of zero is the due date itself, not the day before', () {
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(dueOn: DateTime(2026, 9, 10)),
      ], preferences: const ReminderPreferences(daysBefore: <int>[0]));

      expect(reminders.single.firesAt, DateTime(2026, 9, 10, 9));
    });

    test('and an offset crossing a month boundary lands correctly', () {
      // 2 October minus eight days is 24 September, and the arithmetic has to
      // normalise the month rather than producing a -6th of October.
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(dueOn: DateTime(2026, 10, 2)),
      ], preferences: const ReminderPreferences(daysBefore: <int>[8]));

      expect(reminders.single.firesAt, DateTime(2026, 9, 24, 9));
    });

    test('the chosen time of day is honoured', () {
      final List<BillReminder> reminders = scheduleFor(
        <BillWithStatus>[bill()],
        preferences: const ReminderPreferences(
          daysBefore: <int>[1],
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
      );

      expect(reminders.single.firesAt, DateTime(2026, 9, 9, 18, 30));
    });
  });

  group('what is left out', () {
    test('anything already in the past', () {
      // The 25th at 09:00 has gone; it is 10:00. Scheduling it would either be
      // refused or fire at once — a reminder that a bill is due in three days,
      // arriving late, is worse than none.
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(dueOn: DateTime(2026, 8, 25)),
      ], preferences: const ReminderPreferences(daysBefore: <int>[0]));

      expect(reminders, isEmpty);
    });

    test('but the same day later on still counts', () {
      final List<BillReminder> reminders = scheduleFor(
        <BillWithStatus>[bill(dueOn: DateTime(2026, 8, 25))],
        preferences: const ReminderPreferences(
          daysBefore: <int>[0],
          timeOfDay: ReminderTime(hour: 18, minute: 0),
        ),
      );

      expect(reminders.single.firesAt, DateTime(2026, 8, 25, 18));
    });

    test('a settled bill, which is the one that matters most', () {
      // Paying a bill and then being reminded about it twice more is the single
      // most annoying thing a reminder can do — and exactly what an event-driven
      // scheduler forgets to undo.
      expect(
        scheduleFor(<BillWithStatus>[bill(status: BillStatus.paid)]),
        isEmpty,
      );
    });

    test('an archived bill', () {
      expect(
        scheduleFor(<BillWithStatus>[
          bill(status: BillStatus.archived, archived: true),
        ]),
        isEmpty,
      );
    });

    test('and an overdue one, whose reminders are all in the past anyway', () {
      // Not because it does not matter — it matters most. Saying "this is late"
      // is a different message on a different channel, and Sprint 41's job.
      expect(
        scheduleFor(<BillWithStatus>[
          bill(dueOn: DateTime(2026, 8, 20), status: BillStatus.overdue),
        ]),
        isEmpty,
      );
    });

    test('everything, when the user has turned reminders off', () {
      expect(
        scheduleFor(<BillWithStatus>[
          bill(),
        ], preferences: const ReminderPreferences(isEnabled: false)),
        isEmpty,
      );
    });

    test('and a partly paid bill is still owed, so it still reminds', () {
      expect(
        scheduleFor(<BillWithStatus>[
          bill(status: BillStatus.partiallyPaid, outstanding: 50000),
        ]),
        isNotEmpty,
      );
    });
  });

  group('what each one carries', () {
    test('the bill it is about, and what is still owed', () {
      // The outstanding amount, not the billed one: a bill with ₱1,000 left on
      // ₱1,500 should say ₱1,000.
      final BillReminder reminder = scheduleFor(<BillWithStatus>[
        bill(status: BillStatus.partiallyPaid, outstanding: 100000),
      ]).first;

      expect(reminder.billId, 'bill-1');
      expect(reminder.billName, 'Meralco');
      expect(reminder.amount, '₱1,000.00');
      expect(reminder.dueOn, DateTime(2026, 9, 10));
    });
  });

  group('notification ids', () {
    test('are stable for the same bill and offset', () {
      // The whole reason this is not `String.hashCode`. Dart makes no promise
      // that one is stable across releases, and an id that changes between app
      // versions is a scheduled reminder that can never be cancelled — it fires
      // anyway, beside its own replacement.
      final BillReminder a = BillReminder(
        billId: 'bill-1',
        billName: 'Meralco',
        daysBefore: 3,
        firesAt: anyTime,
        dueOn: anyTime,
        amount: '₱1.00',
      );

      expect(a.notificationId, 193576597);
    });

    test('differ per offset on the same bill', () {
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(),
      ]);
      final Set<int> ids = reminders
          .map((BillReminder r) => r.notificationId)
          .toSet();

      expect(ids, hasLength(reminders.length));
    });

    test('and differ across bills', () {
      final List<BillReminder> reminders = scheduleFor(<BillWithStatus>[
        bill(id: 'a'),
        bill(id: 'b'),
      ]);
      final Set<int> ids = reminders
          .map((BillReminder r) => r.notificationId)
          .toSet();

      expect(ids, hasLength(reminders.length));
    });

    test('and are always positive, which the platform requires', () {
      for (final String id in <String>['a', 'zzz', 'bill-99', '']) {
        const int offset = 3;
        final BillReminder reminder = BillReminder(
          billId: id,
          billName: 'x',
          daysBefore: offset,
          firesAt: anyTime,
          dueOn: anyTime,
          amount: '₱1.00',
        );

        expect(reminder.notificationId, greaterThanOrEqualTo(0));
      }
    });
  });

  group('the preferences themselves', () {
    test('fire furthest-warning first, whatever order they were stored in', () {
      // The column is an array with no ordering guarantee, and nothing stops
      // {0,3,1} being written.
      const ReminderPreferences preferences = ReminderPreferences(
        daysBefore: <int>[0, 3, 1],
      );

      expect(preferences.orderedOffsets, <int>[3, 1, 0]);
    });

    test('and a duplicated offset is one reminder, not two', () {
      // Two notifications on the same day at the same minute is one reminder
      // and one annoyance.
      const ReminderPreferences preferences = ReminderPreferences(
        daysBefore: <int>[3, 3, 1],
      );

      expect(preferences.orderedOffsets, <int>[3, 1]);
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

  group('what the notification says', () {
    BillReminder reminderFor(int daysBefore) => BillReminder(
      billId: 'bill-1',
      billName: 'Rent',
      daysBefore: daysBefore,
      firesAt: anyTime,
      dueOn: DateTime(2026, 9, 10),
      amount: '₱4,000.00',
    );

    test('the bill name leads, not the app name', () {
      // What the reader is scanning for among a dozen other notifications.
      // "PayPaw reminder" would tell them which app and nothing they need.
      expect(reminderFor(3).title, startsWith('Rent'));
    });

    test('and the day is said in words where there is a word for it', () {
      expect(reminderFor(0).title, 'Rent is due today');
      expect(reminderFor(1).title, 'Rent is due tomorrow');
      expect(reminderFor(3).title, 'Rent is due in 3 days');
      expect(reminderFor(7).title, 'Rent is due in 7 days');
    });

    test('the body carries the amount and the date', () {
      // The two things that decide whether to act now, on a lock screen where
      // opening the app is the expensive option.
      expect(reminderFor(3).body, contains('₱4,000.00'));
      expect(reminderFor(3).body, contains('Sep 10'));
    });
  });
}
