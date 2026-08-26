import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/widgets/bill_status_display.dart';
import '../../domain/entities/calendar_month.dart';

/// One month, drawn.
///
/// ## What a square says
///
/// The date, whether it is today, how many bills fall on it, and what state the
/// worst of them is in.
///
/// A count rather than one dot per bill. A day with five bills on it would
/// otherwise be five dots in a square smaller than a fingertip, and the number
/// is the thing worth reading anyway. The colour carries the urgency the number
/// cannot.
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
    required this.billsFor,
    this.selectedDay,
    this.onDayTap,
    super.key,
  });

  final CalendarMonth month;

  /// The date to mark as today, already reduced to a day.
  final DateTime today;

  /// The date the user has picked, if any. Already reduced to a day.
  final DateTime? selectedDay;

  /// The bills falling on a date. Empty for a day with none.
  final List<BillWithStatus> Function(DateTime day) billsFor;

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
                    bills: billsFor(day),
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
              // A node of its own. A bare label annotation has no property that
              // forces one, so it folds into whatever ancestor happens to be a
              // boundary — which changed the moment this grid moved inside a
              // sliver and a gesture detector, and took seven column headings
              // out of the accessibility tree with it.
              container: true,
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
    required this.bills,
    required this.onTap,
  });

  final DateTime day;
  final bool isInMonth;
  final bool isToday;
  final bool isSelected;
  final List<BillWithStatus> bills;
  final VoidCallback? onTap;

  int get count => bills.length;

  /// The status the square wears.
  ///
  /// The loudest of the day's bills, not a blend of them: a day carrying one
  /// overdue bill and two settled ones is an overdue day, and a fourth colour
  /// meaning "mixed" would say nothing anybody could act on. The list under the
  /// grid is where each bill gets its own.
  BillStatus? get status =>
      BillStatus.mostUrgent(bills.map((BillWithStatus item) => item.status));

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
                            child: _DayMarker(
                              count: count,
                              status: status,
                              isToday: isToday,
                            ),
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

  /// What a screen reader says, which is also the only place the colour is
  /// written down in words.
  ///
  /// A square that meant "overdue" by being red alone would mean nothing at all
  /// to anyone who cannot see the difference, and red-green is the most common
  /// way not to.
  String _spokenLabel() {
    final String date = DateFormat.MMMMEEEEd().format(day);
    final String todayPrefix = isToday ? 'Today, ' : '';
    final String selected = isSelected ? ', selected' : '';

    if (count == 0) {
      return '$todayPrefix$date, nothing due$selected';
    }

    final String bills = count == 1 ? '1 bill' : '$count bills';

    return '$todayPrefix$date, $bills, '
        '${BillStatusDisplay.label(status).toLowerCase()}$selected';
  }
}

/// What is due on a day, and how much trouble it is in.
///
/// A pill with a number rather than dots. One dot per bill stops being readable
/// at three, and "how many" is the question a month view is being asked; the
/// colour answers "how urgent" alongside it.
///
/// The tones are the app's own — [BillStatusDisplay.tone] — so a red square here
/// and a red rail on the bills list mean the same thing, learned once. Colour is
/// never the only carrier: the count is written on the badge, the square's
/// spoken label names the status, and the panel below the grid shows every bill
/// with its status in words.
class _DayMarker extends StatelessWidget {
  const _DayMarker({
    required this.count,
    required this.status,
    required this.isToday,
  });

  final int count;
  final BillStatus? status;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AppStatusTone tone = BillStatusDisplay.tone(status);

    // On today's square the background is already the brand colour, and a tint
    // laid over it would be two washes of colour fighting. The card surface
    // underneath the status text separates them instead.
    final Color background = isToday ? colors.surface : colors.statusTint(tone);

    // The number is data, not a label. A neutral chip elsewhere in the app can
    // afford a secondary-grey word on it because the word is furniture; here the
    // digit is the answer, and on the quietest tone it needs to stay crisp.
    final Color foreground = tone == AppStatusTone.neutral
        ? colors.textPrimary
        : colors.statusText(tone);

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
