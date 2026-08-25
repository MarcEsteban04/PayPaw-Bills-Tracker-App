import 'package:flutter/material.dart' show DateUtils;
import 'package:meta/meta.dart';

/// One month, laid out as the grid a calendar draws.
///
/// ## Why the grid is always six rows
///
/// A month needs five rows or six depending on which weekday it starts on, and a
/// grid that changes height between months makes every step forward or back
/// jump the whole screen — including whatever sits under it. Six rows always
/// costs a row of dimmed dates in the shorter months and buys a page that stays
/// still.
///
/// ## Why the dates are built, not stepped
///
/// Every cell is `DateTime(year, month, n)` with `n` allowed to run past the end
/// of the month or below one — the constructor normalises both. Adding
/// `Duration(days: 1)` repeatedly would be the obvious alternative and is wrong
/// twice a year: a day that crosses a DST boundary is 23 or 25 hours long, and
/// the walk drifts into the previous or next date and stays there.
///
/// PayPaw has no DST today — the Philippines has not observed it since 1978 —
/// but a calendar that quietly breaks for anyone who travels is not worth the
/// three characters saved.
@immutable
class CalendarMonth {
  CalendarMonth(int year, int month, {this.firstWeekday = DateTime.sunday})
    : assert(
        firstWeekday >= DateTime.monday && firstWeekday <= DateTime.sunday,
        'firstWeekday must be one of DateTime.monday..DateTime.sunday',
      ),
      // Normalised through the constructor so `CalendarMonth(2026, 13)` is
      // January 2027 rather than a month nothing can render. [next] and
      // [previous] rely on it.
      first = DateTime(year, month);

  /// The month containing [date].
  factory CalendarMonth.of(
    DateTime date, {
    int firstWeekday = DateTime.sunday,
  }) => CalendarMonth(date.year, date.month, firstWeekday: firstWeekday);

  /// The first day of the month, at midnight.
  final DateTime first;

  /// Which weekday a row starts on, as `DateTime.monday`..`DateTime.sunday`.
  ///
  /// Sunday, matching the calendar every Philippine phone ships with. A
  /// parameter rather than a constant because it is the one thing about this
  /// layout that is convention rather than fact, and a test should be able to
  /// say so.
  final int firstWeekday;

  int get year => first.year;
  int get month => first.month;

  /// How many rows the grid always has. See the note above.
  static const int weekCount = 6;

  static const int daysPerWeek = 7;

  /// Every cell in the grid, in reading order, including the dimmed days that
  /// belong to the months on either side.
  late final List<DateTime> days = List<DateTime>.generate(
    weekCount * daysPerWeek,
    (int index) => DateTime(year, month, 1 - _lead + index),
  );

  /// The same cells, one list per row.
  late final List<List<DateTime>> weeks = List<List<DateTime>>.generate(
    weekCount,
    (int week) => days.sublist(week * daysPerWeek, (week + 1) * daysPerWeek),
  );

  /// The weekdays in the order this grid shows them, as
  /// `DateTime.monday`..`DateTime.sunday`.
  ///
  /// For the column headings, so the labels cannot drift out of step with the
  /// cells beneath them.
  late final List<int> weekdays = List<int>.generate(
    daysPerWeek,
    // 1..7 with no zero: the modulo lands on 0 for the seventh, which is the
    // day *before* firstWeekday and has to read as 7, not as an invalid weekday.
    (int index) => (firstWeekday - 1 + index) % daysPerWeek + 1,
  );

  /// How many cells of the previous month lead the grid.
  int get _lead => (first.weekday - firstWeekday) % daysPerWeek;

  /// Whether [day] falls in this month, ignoring the time of day.
  ///
  /// The question every cell asks: a date from the month either side is drawn
  /// dimmed, and tapping it should still work.
  bool contains(DateTime day) => day.year == year && day.month == month;

  CalendarMonth get next =>
      CalendarMonth(year, month + 1, firstWeekday: firstWeekday);

  CalendarMonth get previous =>
      CalendarMonth(year, month - 1, firstWeekday: firstWeekday);

  /// Whether this month is before [other], by calendar position.
  bool isBefore(CalendarMonth other) => first.isBefore(other.first);

  /// How many whole months from [other] to this one. Negative going back.
  ///
  /// Used to decide which way a month change should animate, which a date
  /// comparison cannot answer on its own.
  int monthsFrom(CalendarMonth other) =>
      (year - other.year) * 12 + (month - other.month);

  /// The day-only form of [date], which is the key every lookup here uses.
  ///
  /// A bill's due date arrives at midnight and the device clock does not, so
  /// comparing them raw finds nothing. Exposed because the providers that build
  /// maps against this grid have to key them the same way.
  static DateTime dateOnly(DateTime date) => DateUtils.dateOnly(date);

  @override
  bool operator ==(Object other) =>
      other is CalendarMonth &&
      other.year == year &&
      other.month == month &&
      other.firstWeekday == firstWeekday;

  @override
  int get hashCode => Object.hash(year, month, firstWeekday);

  @override
  String toString() => 'CalendarMonth($year-$month)';
}
