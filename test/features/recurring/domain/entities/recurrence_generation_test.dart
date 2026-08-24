import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';

/// One step of a schedule, as both implementations must compute it.
///
/// The shared contract between `Recurrence.occurrenceAfter` in Dart and
/// `next_recurrence_date` in `0016_generate_recurring_bills.sql`. **The same
/// cases exist in `supabase/checks/recurrence_dates.sql`**, so a divergence
/// between the two shows up as a failure on one side rather than as bills
/// generated on dates the preview never promised.
@immutable
class _Step {
  const _Step({
    required this.frequency,
    required this.dayOfMonth,
    required this.current,
    required this.expected,
    this.interval = 1,
    this.weekday,
    this.monthOfYear,
  });

  final RecurrenceFrequency frequency;
  final int interval;
  final int? dayOfMonth;
  final int? weekday;
  final int? monthOfYear;

  /// An occurrence of the rule. The step is what comes after it.
  final DateTime current;
  final DateTime expected;

  /// A rule anchored so that [current] is one of its occurrences, which is what
  /// makes `occurrenceAfter(current)` the same question the SQL asks.
  Recurrence get rule => Recurrence(
    frequency: frequency,
    intervalCount: interval,
    dayOfMonth: dayOfMonth,
    weekday: weekday,
    monthOfYear: monthOfYear,
    startsOn: current,
  );

  @override
  String toString() =>
      '$frequency every $interval, day $dayOfMonth, from $current';
}

void main() {
  /// Every case `supabase/checks/recurrence_dates.sql` also asserts.
  final List<_Step> sharedCases = <_Step>[
    // Weekly steps whole weeks, so the weekday survives without being consulted.
    _Step(
      frequency: RecurrenceFrequency.weekly,
      dayOfMonth: null,
      weekday: DateTime.monday,
      current: DateTime(2026, 1, 5),
      expected: DateTime(2026, 1, 12),
    ),
    _Step(
      frequency: RecurrenceFrequency.weekly,
      dayOfMonth: null,
      weekday: DateTime.monday,
      interval: 2,
      current: DateTime(2026, 1, 5),
      expected: DateTime(2026, 1, 19),
    ),
    _Step(
      frequency: RecurrenceFrequency.weekly,
      dayOfMonth: null,
      weekday: DateTime.wednesday,
      interval: 2,
      current: DateTime(2026, 12, 30),
      expected: DateTime(2027, 1, 13),
    ),

    // Monthly, plain.
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
      current: DateTime(2026, 1, 15),
      expected: DateTime(2026, 2, 15),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
      current: DateTime(2026, 12, 15),
      expected: DateTime(2027, 1, 15),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
      interval: 3,
      current: DateTime(2026, 1, 15),
      expected: DateTime(2026, 4, 15),
    ),

    // Month ends. The second of these is the whole reason the design resolves
    // the day afresh: stepping from the previous *date* would give 28 March.
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 31,
      current: DateTime(2026, 1, 31),
      expected: DateTime(2026, 2, 28),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 31,
      current: DateTime(2026, 2, 28),
      expected: DateTime(2026, 3, 31),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 30,
      current: DateTime(2026, 1, 30),
      expected: DateTime(2026, 2, 28),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: Recurrence.lastDayOfMonth,
      current: DateTime(2026, 1, 31),
      expected: DateTime(2026, 2, 28),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: Recurrence.lastDayOfMonth,
      current: DateTime(2026, 2, 28),
      expected: DateTime(2026, 3, 31),
    ),

    // Leap years, and the century rule that catches naive implementations.
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 31,
      current: DateTime(2028, 1, 31),
      expected: DateTime(2028, 2, 29),
    ),
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 31,
      current: DateTime(2100, 1, 31),
      expected: DateTime(2100, 2, 28),
    ),

    // Quarterly, crossing a year and a short month at once.
    _Step(
      frequency: RecurrenceFrequency.quarterly,
      dayOfMonth: 10,
      current: DateTime(2026, 2, 10),
      expected: DateTime(2026, 5, 10),
    ),
    _Step(
      frequency: RecurrenceFrequency.quarterly,
      dayOfMonth: 31,
      current: DateTime(2026, 11, 30),
      expected: DateTime(2027, 2, 28),
    ),

    // Yearly. The second one recovers the 29th in the next leap year, which is
    // only possible because the rule is stored rather than the last date used.
    _Step(
      frequency: RecurrenceFrequency.yearly,
      dayOfMonth: 15,
      monthOfYear: 3,
      current: DateTime(2026, 3, 15),
      expected: DateTime(2027, 3, 15),
    ),
    _Step(
      frequency: RecurrenceFrequency.yearly,
      dayOfMonth: 29,
      monthOfYear: 2,
      current: DateTime(2027, 2, 28),
      expected: DateTime(2028, 2, 29),
    ),

    // The largest interval the column allows.
    _Step(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 5,
      interval: 60,
      current: DateTime(2026, 1, 5),
      expected: DateTime(2031, 1, 5),
    ),
  ];

  group('the shared step contract', () {
    test('every case matches what the SQL is checked against', () {
      // If this fails, the preview and the generator disagree — and the bills
      // that appear will not be the dates the user was shown.
      for (final _Step step in sharedCases) {
        expect(
          step.rule.occurrenceAfter(step.current),
          step.expected,
          reason: step.toString(),
        );
      }
    });

    test('and there are enough of them to be worth calling a contract', () {
      // A guard against the list quietly shrinking to the easy cases.
      expect(sharedCases.length, greaterThanOrEqualTo(18));
    });
  });

  group('over a long run', () {
    /// Every occurrence of [rule] from its first, [count] of them.
    List<DateTime> series(Recurrence rule, int count) =>
        rule.occurrencesFrom(rule.startsOn, limit: count);

    test('a 31st schedule never sticks to the 28th', () {
      // The failure this design exists to prevent is invisible for a year and
      // permanent after it: February clamps, and a date-stepping implementation
      // never climbs back. Five years is enough to catch a ratchet.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 31,
        startsOn: DateTime(2026, 1, 2),
      );

      final List<DateTime> dates = series(rule, 60);

      expect(dates, hasLength(60));
      for (final DateTime date in dates) {
        // Always the last possible day at or before the 31st, in that month.
        final int lastDay = DateTime(date.year, date.month + 1, 0).day;
        expect(
          date.day,
          lastDay < 31 ? lastDay : 31,
          reason: 'drifted in ${date.year}-${date.month}',
        );
      }
    });

    test('a last-day schedule is always the last day', () {
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: Recurrence.lastDayOfMonth,
        startsOn: DateTime(2026, 1, 2),
      );

      for (final DateTime date in series(rule, 60)) {
        expect(date.day, DateTime(date.year, date.month + 1, 0).day);
      }
    });

    test('a weekly schedule keeps its weekday for a year', () {
      // The property a `Duration(days: 7)` implementation loses across a
      // daylight-saving boundary: the date creeps by an hour and eventually a
      // day. Calendar arithmetic cannot.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.weekly,
        weekday: DateTime.thursday,
        startsOn: DateTime(2026, 1, 2),
      );

      for (final DateTime date in series(rule, 52)) {
        expect(date.weekday, DateTime.thursday, reason: '$date');
      }
    });

    test('dates strictly increase, so no occurrence can repeat', () {
      // The client half of duplicate prevention. The database half is the unique
      // index on (recurring_bill_id, due_on) — but a generator whose bookmark
      // could stand still would spin against that index forever.
      for (final RecurrenceFrequency frequency in RecurrenceFrequency.values) {
        final Recurrence rule = Recurrence(
          frequency: frequency,
          dayOfMonth: frequency.needsWeekday ? null : 31,
          weekday: frequency.needsWeekday ? DateTime.friday : null,
          monthOfYear: frequency.needsMonthOfYear ? 2 : null,
          startsOn: DateTime(2026, 1, 2),
        );

        final List<DateTime> dates = series(rule, 40);

        expect(dates.toSet(), hasLength(dates.length), reason: '$frequency');
        for (int i = 1; i < dates.length; i++) {
          expect(
            dates[i].isAfter(dates[i - 1]),
            isTrue,
            reason: '$frequency: ${dates[i]} did not follow ${dates[i - 1]}',
          );
        }
      }
    });
  });

  group('resuming from a bookmark', () {
    test('produces the same series as running straight through', () {
      // What generation actually does: it stores `next_due_on`, and a later run
      // picks up from it. If stepping from a stored date gave a different series
      // from stepping in one go, an interrupted run would silently change the
      // schedule.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 31,
        startsOn: DateTime(2026, 1, 2),
      );

      final List<DateTime> straight = rule.occurrencesFrom(
        rule.startsOn,
        limit: 24,
      );

      // The same 24, but restarted from each date as if the app had closed.
      final List<DateTime> resumed = <DateTime>[straight.first];
      while (resumed.length < 24) {
        resumed.add(rule.occurrenceAfter(resumed.last)!);
      }

      expect(resumed, straight);
    });

    test('and asking again from the same bookmark does not advance it', () {
      // Idempotence at the client. Generation runs on every app open; a step
      // that moved on its own would create a bill per launch.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 2),
      );

      final DateTime bookmark = DateTime(2026, 3, 15);

      expect(rule.occurrenceAfter(bookmark), DateTime(2026, 4, 15));
      expect(rule.occurrenceAfter(bookmark), DateTime(2026, 4, 15));
      expect(rule.occurrenceAfter(bookmark), DateTime(2026, 4, 15));
    });
  });

  group('time zones', () {
    test('a due date is a calendar date, with no time on it', () {
      // Every occurrence is local midnight. A time would make comparisons — and
      // therefore the whole schedule — depend on where the device is.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 5, 23, 59, 59),
      );

      for (final DateTime date in rule.occurrencesFrom(
        DateTime(2026, 1, 2),
        limit: 12,
      )) {
        expect(date.hour, 0);
        expect(date.minute, 0);
        expect(date.second, 0);
        expect(date.millisecond, 0);
        expect(date.isUtc, isFalse);
      }
    });

    test('a start time is discarded rather than carried', () {
      // Two templates created the same day at different hours must produce the
      // same schedule.
      final Recurrence morning = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 5, 6),
      );
      final Recurrence night = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 5, 23, 30),
      );

      expect(morning, night);
      expect(
        morning.occurrencesFrom(DateTime(2026, 1, 2), limit: 6),
        night.occurrencesFrom(DateTime(2026, 1, 2), limit: 6),
      );
    });

    test('a UTC start is read as the day it names', () {
      // `DateTime.utc(2026, 1, 5)` is the 5th. Converting it to local first
      // would make it the 4th west of Greenwich, which is how a schedule ends up
      // a day early for half the world.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 20,
        startsOn: DateTime.utc(2026, 1, 5),
      );

      expect(rule.startsOn.day, 5);
      expect(rule.startsOn.month, 1);
      expect(rule.firstOccurrence, DateTime(2026, 1, 20));
    });

    test('the comparison ignores the time on the date it is given', () {
      // Callers pass whatever they have — `DateTime.now()` from a device clock,
      // a timestamp from a row. Late in the evening must not count as the next
      // day.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 2),
      );

      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 15, 23, 59)),
        DateTime(2026, 2, 15),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 14, 0, 1)),
        DateTime(2026, 1, 15),
      );
    });
  });
}
