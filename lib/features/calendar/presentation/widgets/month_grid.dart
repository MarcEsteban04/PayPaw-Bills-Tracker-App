import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/calendar_month.dart';

/// One month, drawn.
///
/// ## What a square says at this sprint
///
/// The date, whether it is today, and whether anything is due on it. Not yet
/// *what* is due — the paid/overdue/upcoming colours are Sprint 45, and a marker
/// that means "something" now becomes a marker that means "something overdue"
/// then without the grid changing shape.
///
/// A count rather than one dot per bill. A day with five bills on it would
/// otherwise be five dots in a square smaller than a fingertip, and the number
/// is the thing worth reading anyway.
///
/// ## The days either side are shown, not blanked
///
/// A grid with holes at both ends reads as broken, and the last days of the
/// previous month are exactly where a bill that has just gone overdue sits.
/// They are dimmed, so the month being looked at is still obvious.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.today,
    required this.countFor,
    this.selectedDay,
    this.onDayTap,
    super.key,
  });

  final CalendarMonth month;

  /// The date to mark as today, already reduced to a day.
  final DateTime today;

  /// The date the user has picked, if any. Already reduced to a day.
  final DateTime? selectedDay;

  /// How many bills fall on a date. Zero for an empty day.
  final int Function(DateTime day) countFor;

  /// Tapping a square.
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _WeekdayHeadings(weekdays: month.weekdays),
        const SizedBox(height: AppSpacing.sm),
        for (final List<DateTime> week in month.weeks)
          Row(
            children: <Widget>[
              for (final DateTime day in week)
                Expanded(
                  child: _DayCell(
                    day: day,
                    isInMonth: month.contains(day),
                    isToday: day == today,
                    isSelected: day == selectedDay,
                    count: countFor(day),
                    onTap: onDayTap == null ? null : () => onDayTap!(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// S M T W T F S, in whatever order the grid runs.
///
/// Built from [CalendarMonth.weekdays] rather than a literal list, so the labels
/// cannot drift out of step with the columns under them when the start day
/// changes.
class _WeekdayHeadings extends StatelessWidget {
  const _WeekdayHeadings({required this.weekdays});

  final List<int> weekdays;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Any week works — this one starts on a Monday, so weekday n is the nth.
    // Formatting a real date is what keeps the abbreviations localised rather
    // than hardcoded English.
    final DateFormat format = DateFormat.E();

    return Row(
      children: <Widget>[
        for (final int weekday in weekdays)
          Expanded(
            child: Semantics(
              // The visible label is one or two letters, which a screen reader
              // spells out. The full name is what it should say.
              label: DateFormat.EEEE().format(DateTime(2024, 1, weekday)),
              excludeSemantics: true,
              child: Text(
                format.format(DateTime(2024, 1, weekday)),
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One square.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isInMonth,
    required this.isToday,
    required this.isSelected,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final bool isInMonth;
  final bool isToday;
  final bool isSelected;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color text = switch ((isToday, isInMonth)) {
      (true, _) => colors.textOnPrimary,
      // Dimmed rather than hidden: the last days of the previous month are
      // exactly where a bill that has just gone overdue sits.
      (false, false) => colors.textTertiary,
      (false, true) => colors.textPrimary,
    };

    return Semantics(
      button: onTap != null,
      label: _spokenLabel(),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: AspectRatio(
          // Square-ish rather than square. A true square across seven columns on
          // a 392dp screen leaves a grid taller than the space above the
          // navigation bar, and the extra height buys nothing: the number sits
          // under the date, not beside it.
          aspectRatio: 0.86,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isToday ? colors.primary : Colors.transparent,
                borderRadius: AppRadii.card,
                // An outline for the picked day, a fill for today. Two marks
                // that can land on the same square, so they cannot be the same
                // mark — picking today would otherwise look like picking
                // nothing.
                border: isSelected
                    ? Border.all(color: colors.primary, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${day.day}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: text,
                      fontWeight: isToday || count > 0
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // The row keeps its height whether or not there is a marker,
                  // so the dates stay on one baseline across the grid.
                  SizedBox(
                    height: _markerHeight,
                    // Centred, so the pill hugs its number. A `SizedBox` passes
                    // a tight height and a loose width, which left the marker
                    // stretched across the whole square — a bar rather than a
                    // badge, and one that looked identical whether it said 1 or
                    // 11.
                    child: count == 0
                        ? null
                        : Center(
                            child: _DayMarker(count: count, isToday: isToday),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _markerHeight = 14;

  String _spokenLabel() {
    final String date = DateFormat.MMMMEEEEd().format(day);
    final String todayPrefix = isToday ? 'Today, ' : '';
    final String selected = isSelected ? ', selected' : '';

    final String due = switch (count) {
      0 => 'nothing due',
      1 => '1 bill due',
      _ => '$count bills due',
    };

    return '$todayPrefix$date, $due$selected';
  }
}

/// What is due on a day, before Sprint 45 gives it a colour.
///
/// A pill with a number rather than dots. One dot per bill stops being readable
/// at three, and "how many" is the question a month view is being asked.
class _DayMarker extends StatelessWidget {
  const _DayMarker({required this.count, required this.isToday});

  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // The brand tint, not `surfaceMuted`.
    //
    // Muted grey on a dark sheet is very nearly the sheet, and on a device this
    // marker read as a smudge — which is the whole failure, since its one job is
    // to be the thing the eye lands on. Sprint 45 replaces the tint with one per
    // status; this is the neutral it starts from.
    //
    // On today's square the background is already the brand colour, so the
    // marker has to invert or it disappears into it.
    final Color background = isToday
        ? colors.textOnPrimary.withValues(alpha: 0.18)
        : colors.primarySoft;
    final Color foreground = isToday
        ? colors.textOnPrimary
        : colors.primaryText;

    // No `alignment`, deliberately. A `Container` given one expands to its
    // constraints rather than hugging its child, which turned this badge into a
    // bar spanning most of the square — identical whether it said 1 or 11.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.round,
      ),
      child: Text(
        '$count',
        style: textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}
