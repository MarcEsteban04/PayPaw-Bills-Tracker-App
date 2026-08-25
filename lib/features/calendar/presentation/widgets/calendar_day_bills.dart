import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';
import '../../domain/entities/calendar_month.dart';

/// What is due, under the grid.
///
/// ## One panel, two questions
///
/// With a day picked it answers "what is due on the 18th". With none picked it
/// answers "what is due this month", which is the question the grid above is
/// already answering in shape — this spells it out, and means the space below a
/// calendar is never empty.
///
/// The alternative was a panel that appears only after a tap. That leaves the
/// bottom half of the screen blank on arrival, which is both a waste and a
/// failure to say that tapping does anything at all.
///
/// ## The rows are the bills list's own
///
/// [BillListTile] rather than a calendar-specific row, so a bill looks the same
/// wherever it is read and the urgency rail keeps meaning what it means. It also
/// means Sprint 45's status work lands here for free.
class CalendarDayBills extends ConsumerWidget {
  const CalendarDayBills({
    required this.month,
    required this.selectedDay,
    required this.byDate,
    required this.onBillTap,
    super.key,
  });

  final CalendarMonth month;

  /// The day picked, or null for the whole month.
  final DateTime? selectedDay;

  final Map<DateTime, List<BillWithStatus>> byDate;

  final void Function(BillWithStatus item) onBillTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<DateTime> dates = _dates();
    final int count = dates.fold<int>(
      0,
      (int sum, DateTime date) => sum + (byDate[date]?.length ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            _heading(),
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (count == 0)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              selectedDay == null
                  ? 'Nothing is due this month.'
                  : 'Nothing is due on this day.',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          )
        else
          for (final DateTime date in dates) ...<Widget>[
            // The date above each group, but only when there is more than one
            // group to tell apart. On a single day it would repeat the heading
            // two lines above it.
            if (selectedDay == null && dates.length > 1) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  DateFormat.MMMEd().format(date),
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            for (final BillWithStatus item in byDate[date]!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: BillListTile(item: item, onTap: () => onBillTap(item)),
              ),
          ],
      ],
    );
  }

  /// The dates this panel covers, soonest first.
  List<DateTime> _dates() {
    if (selectedDay case final DateTime day) {
      return <DateTime>[day];
    }

    final List<DateTime> inMonth = byDate.keys.where(month.contains).toList()
      ..sort();

    return inMonth;
  }

  String _heading() {
    if (selectedDay case final DateTime day) {
      return DateFormat.MMMMEEEEd().format(day);
    }

    return 'Due in ${DateFormat.MMMM().format(month.first)}';
  }
}
