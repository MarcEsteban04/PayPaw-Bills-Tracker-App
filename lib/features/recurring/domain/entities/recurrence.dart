import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import 'recurrence_frequency.dart';

/// When a repeating obligation falls due.
///
/// The structured columns of `recurring_bills`, as one value object, plus the
/// arithmetic that turns them into dates.
///
/// ## Occurrences come from the pattern, never from the last occurrence
///
/// This is the whole design, and it is what keeps month-end right. A bill due on
/// the 31st resolves to 31 January, 28 February, 31 March — because each month
/// asks [dayOfMonth] afresh and clamps it to that month's length. Stepping from
/// the *previous* occurrence instead would give 31 January, 28 February, then 28
/// March, and the schedule would ratchet earlier every February until it stuck on
/// the 28th forever. That bug is invisible for a year and then permanent.
///
/// [dayOfMonth] of `-1` means the last day of the month, rather than storing 31
/// and hoping. February exists.
///
/// ## Dates, not moments
///
/// Every date here is local midnight, normalised on construction. A due date is
/// the same day in every time zone, and stepping with `Duration(days: 7)` would
/// drift by an hour across a daylight-saving boundary — so the arithmetic uses
/// `DateTime(y, m, d + n)`, which is calendar arithmetic and stays at midnight.
/// Dart normalises the overflow, so day 32 of January is 1 February and month 13
/// is next January.
@immutable
class Recurrence {
  Recurrence({
    required this.frequency,
    required DateTime startsOn,
    this.intervalCount = 1,
    this.dayOfMonth,
    this.weekday,
    this.monthOfYear,
    DateTime? endsOn,
  }) : startsOn = _dateOnly(startsOn),
       endsOn = endsOn == null ? null : _dateOnly(endsOn);

  final RecurrenceFrequency frequency;

  /// "Every 2 months", "every 3 weeks". The column allows 1 to 60.
  final int intervalCount;

  /// 1 to 31, or -1 for the last day of the month. Null for [weekly] rules.
  final int? dayOfMonth;

  /// 1 (Monday) to 7 (Sunday), matching `DateTime.weekday` and ISO-8601.
  ///
  /// Only meaningful for [weekly]. The convention matters: getting it wrong shifts
  /// every occurrence by a fixed number of days, which looks like a timezone bug
  /// and is not one.
  final int? weekday;

  /// 1 to 12. Only meaningful for [yearly].
  final int? monthOfYear;

  /// The first date the rule is allowed to produce an occurrence on or after.
  final DateTime startsOn;

  /// The last date it may produce one on, or null for open-ended.
  final DateTime? endsOn;

  /// Sentinel for [dayOfMonth] meaning the last day of whatever month it lands in.
  static const int lastDayOfMonth = -1;

  /// Why this rule cannot be stored, or null when it can.
  ///
  /// Mirrors the check constraints in `0005_recurring_bills.sql` — including
  /// `recurring_bills_recurrence_shape`, which is the one that stops a "monthly"
  /// template with no day of month. Duplicated here on purpose: the database
  /// refusing an insert is the right backstop, but a form that says what is wrong
  /// before the round trip is the right experience, and a monthly rule with no day
  /// would otherwise surface much later as an occurrence that never generates.
  String? validate() {
    if (intervalCount < 1 || intervalCount > 60) {
      return 'Repeat every 1 to 60.';
    }
    if (endsOn case final DateTime end when end.isBefore(startsOn)) {
      return 'The end date cannot be before the start date.';
    }

    if (frequency.needsWeekday) {
      if (weekday == null || weekday! < 1 || weekday! > 7) {
        return 'Choose which day of the week.';
      }
    } else {
      final int? day = dayOfMonth;
      if (day == null || (day != lastDayOfMonth && (day < 1 || day > 31))) {
        return 'Choose which day of the month.';
      }
    }

    if (frequency.needsMonthOfYear) {
      if (monthOfYear == null || monthOfYear! < 1 || monthOfYear! > 12) {
        return 'Choose which month.';
      }
    }

    return null;
  }

  bool get isValid => validate() == null;

  /// The first date this rule falls due on, or null if it ends before it starts.
  ///
  /// A rule whose [endsOn] precedes its first occurrence produces nothing. That is
  /// a real state — "monthly on the 15th, ending the 10th" — and it has to answer
  /// null rather than a date outside its own range.
  DateTime? get firstOccurrence => _withinRange(_firstCandidate());

  /// The next occurrence strictly after [date], or null when the rule is finished.
  ///
  /// Strictly after, so passing the current occurrence advances rather than
  /// returning it. That is what generation needs: `next_due_on` is a bookmark, and
  /// a step that could return where it already was would generate the same bill
  /// twice.
  DateTime? occurrenceAfter(DateTime date) {
    final DateTime after = _dateOnly(date);
    final DateTime first = _firstCandidate();

    if (after.isBefore(first)) {
      return _withinRange(first);
    }

    return _withinRange(
      frequency == RecurrenceFrequency.weekly
          ? _weeklyAfter(first, after)
          : _monthlyAfter(after),
    );
  }

  /// The next [limit] occurrences on or after [from], soonest first.
  ///
  /// For the "next occurrence" preview in Sprint 30, and for generation to catch
  /// up when the app has not been opened in a while. Stops early at [endsOn]
  /// rather than padding the list, so a caller can tell a finite rule from an
  /// open-ended one by counting.
  List<DateTime> occurrencesFrom(DateTime from, {int limit = 3}) {
    final List<DateTime> dates = <DateTime>[];
    // One day back, because `occurrenceAfter` is exclusive and a caller asking
    // "from today" means today counts.
    DateTime cursor = _dateOnly(from).subtract(const Duration(days: 1));

    while (dates.length < limit) {
      final DateTime? next = occurrenceAfter(cursor);
      if (next == null) {
        break;
      }
      dates.add(next);
      cursor = next;
    }

    return dates;
  }

  /// The rule in words: 'Every 2 weeks on Monday', 'Every month on the last day'.
  String describe() {
    final String every = intervalCount == 1
        ? 'Every $_unitSingular'
        : 'Every $intervalCount $_unitPlural';

    return switch (frequency) {
      RecurrenceFrequency.weekly => '$every on ${_weekdayName()}',
      RecurrenceFrequency.yearly => '$every on ${_dayAndMonth()}',
      _ => '$every on the ${_dayName()}',
    };
  }

  String get _unitSingular => switch (frequency) {
    RecurrenceFrequency.weekly => 'week',
    RecurrenceFrequency.monthly => 'month',
    RecurrenceFrequency.quarterly => 'quarter',
    RecurrenceFrequency.yearly => 'year',
  };

  String get _unitPlural => '${_unitSingular}s';

  String _weekdayName() {
    // Only the name is wanted, so any week works as an anchor. 4 January 2026 is
    // a Sunday, so +1 is Monday (weekday 1) and +7 is Sunday (weekday 7) — the
    // ISO numbering `DateTime.weekday` uses.
    final DateTime anchor = DateTime(2026, 1, 4 + (weekday ?? 1));

    return DateFormat.EEEE().format(anchor);
  }

  String _dayName() =>
      dayOfMonth == lastDayOfMonth ? 'last day' : _ordinal(dayOfMonth ?? 1);

  String _dayAndMonth() {
    final String month = DateFormat.MMMM().format(
      DateTime(2026, monthOfYear ?? 1),
    );

    return dayOfMonth == lastDayOfMonth
        ? 'the last day of $month'
        : '${_ordinal(dayOfMonth ?? 1)} of $month';
  }

  static String _ordinal(int day) {
    // 11th, 12th, 13th are the exceptions the naive rule gets wrong.
    if (day % 100 >= 11 && day % 100 <= 13) {
      return '${day}th';
    }

    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  // ---------------------------------------------------------------------------
  // Arithmetic.
  // ---------------------------------------------------------------------------

  /// The first date matching the pattern on or after [startsOn], ignoring
  /// [endsOn].
  DateTime _firstCandidate() {
    if (frequency == RecurrenceFrequency.weekly) {
      // How many days forward to the wanted weekday. Zero when startsOn already
      // is that day, so a rule starting on its own weekday begins that day.
      final int shift = ((weekday ?? startsOn.weekday) - startsOn.weekday) % 7;

      return _plusDays(startsOn, shift);
    }

    final int step = _monthStep;
    final int anchor = frequency == RecurrenceFrequency.yearly
        // A yearly rule's month is fixed by the rule, not by when it started.
        ? startsOn.year * 12 + ((monthOfYear ?? startsOn.month) - 1)
        : startsOn.year * 12 + (startsOn.month - 1);

    final DateTime candidate = _resolveMonth(anchor);

    // One adjustment is enough: a step is at least a month, and adding months
    // only ever moves a date later.
    return candidate.isBefore(startsOn)
        ? _resolveMonth(anchor + step)
        : candidate;
  }

  DateTime _weeklyAfter(DateTime first, DateTime after) {
    final int step = intervalCount * 7;
    final int elapsed = after.difference(first).inDays;
    // Floor then +1, so a date landing exactly on an occurrence advances past it.
    final int k = (elapsed ~/ step) + 1;

    return _plusDays(first, k * step);
  }

  DateTime _monthlyAfter(DateTime after) {
    final int step = _monthStep;
    final DateTime first = _firstCandidate();
    final int anchor = first.year * 12 + (first.month - 1);

    // An estimate, then walk. The estimate can be one step out because clamping a
    // day to a short month moves the date earlier within its month, so the
    // arithmetic on month indices cannot decide the comparison on its own.
    final int target = after.year * 12 + (after.month - 1);
    int k = (target - anchor) ~/ step;
    if (k < 0) {
      k = 0;
    }

    // Bounded rather than `while (true)`: three iterations is already more than
    // clamping can account for, and a loop that cannot terminate is worse than a
    // date that is wrong.
    for (int attempt = 0; attempt < 4; attempt++) {
      final DateTime candidate = _resolveMonth(anchor + k * step);
      if (candidate.isAfter(after)) {
        return candidate;
      }
      k++;
    }

    return _resolveMonth(anchor + k * step);
  }

  /// Months per step, for everything except weekly.
  int get _monthStep => (frequency.monthsPerStep ?? 1) * intervalCount;

  /// The occurrence in the month at [monthIndex] (years × 12 + month − 1).
  ///
  /// Resolving [dayOfMonth] against *this* month is the part that keeps the
  /// schedule from drifting: the 31st becomes the 28th in February and the 31st
  /// again in March.
  DateTime _resolveMonth(int monthIndex) {
    final int year = monthIndex ~/ 12;
    final int month = monthIndex % 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    final int day = dayOfMonth == lastDayOfMonth
        ? lastDay
        : (dayOfMonth ?? 1).clamp(1, lastDay);

    return DateTime(year, month, day);
  }

  DateTime? _withinRange(DateTime date) {
    if (date.isBefore(startsOn)) {
      return null;
    }
    if (endsOn case final DateTime end when date.isAfter(end)) {
      return null;
    }

    return date;
  }

  static DateTime _plusDays(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Recurrence copyWith({
    RecurrenceFrequency? frequency,
    int? intervalCount,
    int? dayOfMonth,
    int? weekday,
    int? monthOfYear,
    DateTime? startsOn,
    DateTime? endsOn,
  }) => Recurrence(
    frequency: frequency ?? this.frequency,
    intervalCount: intervalCount ?? this.intervalCount,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    weekday: weekday ?? this.weekday,
    monthOfYear: monthOfYear ?? this.monthOfYear,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
  );

  /// Clears the nullable fields, which [copyWith] cannot.
  ///
  /// Changing frequency is the reason this exists: a rule switching from yearly to
  /// weekly has to drop its month of year, and a `copyWith` where null means
  /// "leave it alone" has no way to say so. The same pattern as `Bill.clearing`.
  Recurrence clearing({
    bool endsOn = false,
    bool dayOfMonth = false,
    bool weekday = false,
    bool monthOfYear = false,
  }) => Recurrence(
    frequency: frequency,
    intervalCount: intervalCount,
    dayOfMonth: dayOfMonth ? null : this.dayOfMonth,
    weekday: weekday ? null : this.weekday,
    monthOfYear: monthOfYear ? null : this.monthOfYear,
    startsOn: startsOn,
    endsOn: endsOn ? null : this.endsOn,
  );

  @override
  bool operator ==(Object other) =>
      other is Recurrence &&
      other.frequency == frequency &&
      other.intervalCount == intervalCount &&
      other.dayOfMonth == dayOfMonth &&
      other.weekday == weekday &&
      other.monthOfYear == monthOfYear &&
      other.startsOn == startsOn &&
      other.endsOn == endsOn;

  @override
  int get hashCode => Object.hash(
    frequency,
    intervalCount,
    dayOfMonth,
    weekday,
    monthOfYear,
    startsOn,
    endsOn,
  );

  @override
  String toString() => 'Recurrence(${describe()}, from $startsOn)';
}
