import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';
import '../../domain/entities/calendar_month.dart';

/// One line in the list under the grid: a date, or a bill.
///
/// The list is one flat sequence rather than a column of groups, because a
/// sliver can only be lazy over a flat sequence — and being lazy is the whole
/// point. See [CalendarBillsSliver].
sealed class CalendarListEntry {
  const CalendarListEntry();
}

/// The date a run of bills falls on.
class CalendarDateEntry extends CalendarListEntry {
  const CalendarDateEntry(this.date);

  final DateTime date;
}

class CalendarBillEntry extends CalendarListEntry {
  const CalendarBillEntry(this.item);

  final BillWithStatus item;
}

/// Flattens what should be listed into one sequence.
///
/// Pure, and separate from the widget, because the rules are worth testing on
/// their own: which dates appear, in what order, and when a date is worth
/// naming at all.
///
/// A date heading is only emitted when there is more than one date to tell
/// apart. On a single day it would repeat the section heading two lines above
/// it.
List<CalendarListEntry> calendarListEntries({
  required CalendarMonth month,
  required DateTime? selectedDay,
  required Map<DateTime, List<BillWithStatus>> byDate,
}) {
  if (selectedDay case final DateTime day) {
    return <CalendarListEntry>[
      for (final BillWithStatus item in byDate[day] ?? const <BillWithStatus>[])
        CalendarBillEntry(item),
    ];
  }

  final List<DateTime> dates = byDate.keys.where(month.contains).toList()
    ..sort();

  final bool nameTheDates = dates.length > 1;

  return <CalendarListEntry>[
    for (final DateTime date in dates) ...<CalendarListEntry>[
      if (nameTheDates) CalendarDateEntry(date),
      for (final BillWithStatus item in byDate[date]!) CalendarBillEntry(item),
    ],
  ];
}

/// What is due, under the grid.
///
/// ## A sliver, because a month can be long
///
/// This used to be a `Column` inside the screen's `SingleChildScrollView`, which
/// builds every child whether or not any of them can be seen. Measured: a month
/// with two hundred bills built two hundred rows, on a screen where four fit,
/// on every rebuild — including every tap on a date. As a `SliverList` the cost
/// is a screenful.
///
/// ## The rows are the bills list's own
///
/// [BillListTile] rather than a calendar-specific row, so a bill looks the same
/// wherever it is read and the urgency rail keeps meaning what it means.
class CalendarBillsSliver extends ConsumerWidget {
  const CalendarBillsSliver({
    required this.entries,
    required this.selectedDay,
    required this.onBillTap,
    super.key,
  });

  final List<CalendarListEntry> entries;

  /// Only to word the empty state — "this day" reads wrong for a whole month.
  final DateTime? selectedDay;

  final void Function(BillWithStatus item) onBillTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return SliverToBoxAdapter(child: _Empty(selectedDay: selectedDay));
    }

    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) =>
          switch (entries[index]) {
            CalendarDateEntry(date: final DateTime date) => _DateHeading(
              date: date,
            ),
            CalendarBillEntry(item: final BillWithStatus item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: BillListTile(item: item, onTap: () => onBillTap(item)),
            ),
          },
    );
  }
}

class _DateHeading extends StatelessWidget {
  const _DateHeading({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        DateFormat.MMMEd().format(date),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.selectedDay});

  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        selectedDay == null
            ? 'Nothing is due this month.'
            : 'Nothing is due on this day.',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}

/// The heading above the list.
///
/// Its own widget because it sits in the screen's header sliver while the rows
/// sit in a lazy one — they are drawn by different mechanisms and only read as
/// one block.
class CalendarBillsHeading extends StatelessWidget {
  const CalendarBillsHeading({
    required this.month,
    required this.selectedDay,
    super.key,
  });

  final CalendarMonth month;
  final DateTime? selectedDay;

  /// The words, exposed so the screen can use them for the sliver's semantics
  /// and so a test can name what it is looking at.
  static String label({
    required CalendarMonth month,
    required DateTime? selectedDay,
  }) {
    if (selectedDay case final DateTime day) {
      return 'Due ${DateFormat.MMMMEEEEd().format(day)}';
    }

    return 'Due in ${DateFormat.MMMM().format(month.first)}';
  }

  @override
  Widget build(BuildContext context) {
    final String heading = label(month: month, selectedDay: selectedDay);

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.md,
      ),
      child: Semantics(
        header: true,
        // Spoken as what it heads rather than as a bare date. The visible text
        // is "Due Friday, September 18", which read aloud on its own is
        // indistinguishable from the grid square of the same name.
        label: 'Bills ${heading.toLowerCase()}',
        excludeSemantics: true,
        child: Text(
          heading,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
