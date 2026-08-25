import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../bills/domain/entities/bill_with_status.dart';
import 'bill_reminder_override.dart';
import 'notification_channel.dart';
import 'reminder_preferences.dart';
import 'reminder_time.dart';

/// The two things PayPaw has to say about a bill, and when.
///
/// They are separate because they are separate messages, not two settings of
/// one. A reminder is a courtesy before the fact; "this is late" is the thing a
/// bills app exists to say. Each carries its own channel, so a user who silences
/// one has not silenced the other — see [NotificationChannel].
enum BillNoticeKind {
  /// Ahead of the due date. [BillNotice.days] counts back from it.
  reminder(NotificationChannel.billReminders),

  /// After the due date, and still unpaid. [BillNotice.days] counts forward.
  overdue(NotificationChannel.overdueBills);

  const BillNoticeKind(this.channel);

  final NotificationChannel channel;
}

/// One notification, resolved to a moment.
@immutable
class BillNotice {
  const BillNotice({
    required this.kind,
    required this.billId,
    required this.billName,
    required this.days,
    required this.firesAt,
    required this.dueOn,
    required this.amount,
  });

  final BillNoticeKind kind;
  final String billId;
  final String billName;

  /// How far this sits from the due date, in days — *before* it for a reminder
  /// and *after* it for an overdue notice.
  ///
  /// Always positive, with one exception: a reminder at `0` is the due date
  /// itself. Which side of the date it falls on is [kind]'s business, not a
  /// sign bit's; a negative number here would be readable exactly once.
  final int days;

  /// Local wall-clock time it should arrive. Not a UTC instant: the scheduler
  /// wants "9am where the user is", and the zone is applied by the layer that
  /// talks to the platform.
  final DateTime firesAt;

  final DateTime dueOn;

  /// What is still owed, formatted. Carried rather than re-derived so the
  /// notification text is written once.
  final String amount;

  /// What it says on the lock screen.
  ///
  /// The bill's name leads in both kinds. That is what the reader is scanning
  /// for among a dozen other notifications; "PayPaw reminder" would tell them
  /// which app and nothing they need.
  String get title => switch (kind) {
    BillNoticeKind.reminder => switch (days) {
      0 => '$billName is due today',
      1 => '$billName is due tomorrow',
      final int d => '$billName is due in $d days',
    },
    // "Overdue" without a number on the first one: a day late is a lapse, and
    // "1 day overdue" reads like a bank statement. After that the count is the
    // point — the gap is what tells the reader how bad this has got.
    BillNoticeKind.overdue => switch (days) {
      1 => '$billName is overdue',
      final int d => '$billName is $d days overdue',
    },
  };

  /// The amount and the date — the two things that decide whether to act now.
  String get body => switch (kind) {
    BillNoticeKind.reminder =>
      '$amount · due ${DateFormat.MMMEd().format(dueOn)}',
    BillNoticeKind.overdue =>
      '$amount · was due ${DateFormat.MMMEd().format(dueOn)}',
  };

  /// A unique id for the platform scheduler.
  ///
  /// Android notification ids are 32-bit ints and a bill id is a UUID, so it has
  /// to be hashed. The kind is in the key as well as the offset: without it a
  /// reminder three days before and an overdue notice three days after the same
  /// bill would collide, and the second would silently replace the first.
  ///
  /// FNV-1a rather than `String.hashCode`, which Dart does not promise is stable
  /// across releases. Stability is not load-bearing — the scheduler cancels
  /// every pending notification before laying down a new set, so an id only has
  /// to be unique within one pass — but a specified hash is reproducible in a
  /// test, and a collision would drop a notice with no sign that it happened.
  int get notificationId => _fnv1a('$billId:${kind.name}:$days') & 0x7FFFFFFF;

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
      other is BillNotice &&
      other.kind == kind &&
      other.billId == billId &&
      other.days == days &&
      other.firesAt == firesAt;

  @override
  int get hashCode => Object.hash(kind, billId, days, firesAt);

  @override
  String toString() => 'BillNotice(${kind.name}, $billName, $days, $firesAt)';
}

/// Works out which notifications should currently exist.
///
/// ## A pure function over the whole set, not an event handler
///
/// The alternative — schedule on create, cancel on delete, adjust on edit — is
/// a dozen places that each have to remember the rules, and every one of them a
/// chance to leave a notice scheduled for a bill that was paid last week. This
/// takes the bills as they are now and says what the schedule should be; the
/// caller cancels everything and lays down the answer.
///
/// It is also the only way the rules below are testable without a device.
abstract final class BillNoticeSchedule {
  /// How long after the due date PayPaw keeps saying a bill is late.
  ///
  /// ## Why it decays and then stops
  ///
  /// "This is late" is true every morning until the bill is paid, which makes
  /// it the one message that can be sent forever. Sending it daily is how a
  /// forgotten ₱200 bill turns into a month of alerts and the user switches the
  /// channel off — losing the notification the app most needed to deliver.
  ///
  /// So it escalates and ends: the day after, then three, a week, a fortnight.
  /// Four alerts spread over two weeks, and then silence. By day fourteen the
  /// user is not failing to pay because they forgot, and a fifth notification
  /// would be the app insisting rather than informing. The bill is still there,
  /// still red, still at the top of the list.
  ///
  /// Fixed rather than a setting, and deliberately still so after Sprint 42 gave
  /// the other offsets a screen. Neither `reminder_preferences` nor
  /// `bill_reminders` has a column for the days *after* a due date, and a
  /// setting for how often to be told a bill is late is a setting for how much
  /// to be nagged — the answer to which is nobody's but the app's.
  static const List<int> overdueDays = <int>[1, 3, 7, 14];

  /// The notifications that should be scheduled, soonest first.
  ///
  /// [now] is passed in rather than read from the clock, so this stays pure.
  static List<BillNotice> of(
    List<BillWithStatus> bills, {
    required ReminderPreferences preferences,
    required DateTime now,
    Map<String, BillReminderOverride> overrides =
        const <String, BillReminderOverride>{},
  }) {
    final List<BillNotice> notices = <BillNotice>[];

    for (final BillWithStatus item in bills) {
      if (!_wantsNotices(item)) {
        continue;
      }

      // Resolved per bill, because a bill can carry its own rules. Absent an
      // override this is the defaults themselves, which is the common case and
      // costs one map lookup.
      final ReminderPreferences rules =
          overrides[item.bill.id]?.resolve(preferences) ?? preferences;

      // One switch for both kinds. It reads "reminders", but it is the user
      // asking PayPaw not to notify them about this — and honouring that for
      // the gentler message while overriding it for the blunter one would be
      // the app deciding it knows better. Android's per-channel toggles are the
      // finer control for someone who wants only one of the two.
      //
      // Checked inside the loop now rather than once at the top: with per-bill
      // overrides "off" is no longer all-or-nothing, and a bill can be silenced
      // while the rest of them are not.
      if (!rules.isEnabled) {
        continue;
      }

      for (final int days in rules.orderedOffsets) {
        _add(
          notices,
          item: item,
          kind: BillNoticeKind.reminder,
          days: days,
          firesAt: _at(item.bill.dueOn, -days, rules.timeOfDay),
          now: now,
        );
      }

      for (final int days in overdueDays) {
        _add(
          notices,
          item: item,
          kind: BillNoticeKind.overdue,
          days: days,
          firesAt: _at(item.bill.dueOn, days, rules.timeOfDay),
          now: now,
        );
      }
    }

    return notices
      ..sort((BillNotice a, BillNotice b) => a.firesAt.compareTo(b.firesAt));
  }

  /// Adds one notice, unless its moment has passed.
  ///
  /// **The past filter is also the anti-spam rule that is easiest to miss.** A
  /// bill entered when it is already ten days late has three overdue offsets
  /// behind it; without this it would fire all three at once, the moment it was
  /// saved. Scheduling only what is still ahead means a late bill is announced
  /// once, at its next step, rather than in a burst.
  static void _add(
    List<BillNotice> notices, {
    required BillWithStatus item,
    required BillNoticeKind kind,
    required int days,
    required DateTime firesAt,
    required DateTime now,
  }) {
    if (!firesAt.isAfter(now)) {
      return;
    }

    notices.add(
      BillNotice(
        kind: kind,
        billId: item.bill.id,
        billName: item.bill.name,
        days: days,
        firesAt: firesAt,
        dueOn: item.bill.dueOn,
        amount: item.outstanding.format(),
      ),
    );
  }

  /// Whether a bill should produce notifications at all.
  ///
  /// Settled bills are the important exclusion: paying a bill and then being
  /// told about it twice more is the single most annoying thing a notification
  /// can do, and it is exactly what an event-driven scheduler forgets.
  ///
  /// **Overdue bills are included now.** Sprint 40 excluded them, correctly:
  /// every reminder for a bill already late is in the past, so nothing was
  /// scheduled either way. Their overdue notices are not — a bill that went
  /// late yesterday still has three steps ahead of it.
  static bool _wantsNotices(BillWithStatus item) =>
      !item.bill.isArchived && (item.status?.isOutstanding ?? false);

  /// The due date, shifted by [offsetDays], at the user's chosen time.
  ///
  /// Built from parts rather than by adding a `Duration`: a due date is a date,
  /// the reminder time is a time of day, and `dueOn.add(Duration(days: 3))`
  /// across a DST boundary lands an hour out. `DateTime(y, m, d + n)` normalises
  /// the month and year itself and keeps the wall clock exact.
  static DateTime _at(DateTime dueOn, int offsetDays, ReminderTime at) =>
      DateTime(
        dueOn.year,
        dueOn.month,
        dueOn.day + offsetDays,
        at.hour,
        at.minute,
      );
}
