import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import 'reminder_preferences.dart';
import 'reminder_time.dart';

/// One reminder, resolved to a moment.
@immutable
class BillReminder {
  const BillReminder({
    required this.billId,
    required this.billName,
    required this.daysBefore,
    required this.firesAt,
    required this.dueOn,
    required this.amount,
  });

  final String billId;
  final String billName;

  /// How far ahead of the due date this one is. `0` is the due date itself.
  final int daysBefore;

  /// Local wall-clock time it should arrive. Not a UTC instant: the scheduler
  /// wants "9am where the user is", and the zone is applied by the layer that
  /// talks to the platform.
  final DateTime firesAt;

  final DateTime dueOn;

  /// What is still owed, formatted. Carried rather than re-derived so the
  /// notification text is written once.
  final String amount;

  /// What the notification says on the lock screen.
  ///
  /// The bill's name leads. That is what the reader is scanning for among a
  /// dozen other notifications; "PayPaw reminder" would tell them which app and
  /// nothing they need.
  ///
  /// Here rather than in the Android layer because it is a property of the
  /// reminder, not of the platform — and because a private method inside a
  /// method-channel wrapper is a string nobody can test.
  String get title => switch (daysBefore) {
    0 => '$billName is due today',
    1 => '$billName is due tomorrow',
    final int days => '$billName is due in $days days',
  };

  /// The amount and the date — the two things that decide whether to act now.
  String get body => '$amount · due ${DateFormat.MMMEd().format(dueOn)}';

  /// A stable, unique id for the platform scheduler.
  ///
  /// Android notification ids are 32-bit ints, and a bill id is a UUID, so it
  /// has to be hashed. **Not `String.hashCode`**: Dart makes no promise that it
  /// is stable across releases, and an id that changes between app versions is
  /// a scheduled reminder that can never be cancelled — it fires anyway, beside
  /// its own replacement.
  ///
  /// FNV-1a instead: a few lines, specified, and identical on every platform and
  /// every version. Truncated to 31 bits because the platform wants a positive
  /// int.
  int get notificationId => _fnv1a('$billId:$daysBefore') & 0x7FFFFFFF;

  static int _fnv1a(String value) {
    int hash = 0x811C9DC5;

    for (final int unit in value.codeUnits) {
      hash ^= unit;
      // Multiply by the FNV prime, kept inside 32 bits. Dart ints are 64-bit,
      // so the mask is what makes this the specified algorithm rather than
      // something that merely resembles it.
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    return hash;
  }

  @override
  bool operator ==(Object other) =>
      other is BillReminder &&
      other.billId == billId &&
      other.daysBefore == daysBefore &&
      other.firesAt == firesAt;

  @override
  int get hashCode => Object.hash(billId, daysBefore, firesAt);

  @override
  String toString() =>
      'BillReminder($billName, $daysBefore days before, at $firesAt)';
}

/// Works out which reminders should currently exist.
///
/// ## A pure function over the whole set, not an event handler
///
/// The alternative — schedule on create, cancel on delete, adjust on edit — is
/// a dozen places that each have to remember the rules, and every one of them a
/// chance to leave an orphan reminder scheduled for a bill that was paid last
/// week. This takes the bills as they are now and says what the schedule should
/// be; the caller cancels everything and lays down the answer.
///
/// It is also the only way the rules below are testable without a device.
abstract final class BillReminderSchedule {
  /// The reminders that should be scheduled, soonest first.
  ///
  /// [now] is passed in rather than read from the clock, so this stays pure.
  static List<BillReminder> of(
    List<BillWithStatus> bills, {
    required ReminderPreferences preferences,
    required DateTime now,
  }) {
    if (!preferences.isEnabled) {
      return const <BillReminder>[];
    }

    final List<BillReminder> reminders = <BillReminder>[];

    for (final BillWithStatus item in bills) {
      if (!_wantsReminders(item)) {
        continue;
      }

      for (final int daysBefore in preferences.orderedOffsets) {
        final DateTime firesAt = _firingTime(
          dueOn: item.bill.dueOn,
          daysBefore: daysBefore,
          at: preferences.timeOfDay,
        );

        // Already past. The scheduler would either refuse it or fire it
        // immediately, and a notification saying a bill is due in three days,
        // arriving the day after it was due, is worse than none.
        if (!firesAt.isAfter(now)) {
          continue;
        }

        reminders.add(
          BillReminder(
            billId: item.bill.id,
            billName: item.bill.name,
            daysBefore: daysBefore,
            firesAt: firesAt,
            dueOn: item.bill.dueOn,
            amount: item.outstanding.format(),
          ),
        );
      }
    }

    return reminders..sort(
      (BillReminder a, BillReminder b) => a.firesAt.compareTo(b.firesAt),
    );
  }

  /// Whether a bill should produce reminders at all.
  ///
  /// Settled bills are the important exclusion: paying a bill and then being
  /// reminded about it twice more is the single most annoying thing a reminder
  /// can do, and it is exactly what an event-driven scheduler forgets.
  ///
  /// Overdue bills are excluded too, and not because they do not matter — they
  /// matter most. Their reminders are all in the past by definition, so nothing
  /// would be scheduled anyway; saying "this is late" is Sprint 41's job and its
  /// own channel.
  static bool _wantsReminders(BillWithStatus item) =>
      !item.bill.isArchived &&
      item.status != BillStatus.overdue &&
      (item.status?.isOutstanding ?? false);

  /// The due date, moved back [daysBefore] days, at the user's chosen time.
  ///
  /// Built from parts rather than by subtracting a `Duration`: a due date is a
  /// date, the reminder time is a time of day, and `dueOn.subtract(Duration(days:
  /// 3))` across a DST boundary lands an hour out. `DateTime(y, m, d - n)`
  /// normalises the month and year itself and keeps the wall clock exact.
  static DateTime _firingTime({
    required DateTime dueOn,
    required int daysBefore,
    required ReminderTime at,
  }) => DateTime(
    dueOn.year,
    dueOn.month,
    dueOn.day - daysBefore,
    at.hour,
    at.minute,
  );
}
