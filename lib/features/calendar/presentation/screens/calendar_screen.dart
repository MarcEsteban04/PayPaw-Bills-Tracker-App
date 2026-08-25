import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../domain/entities/calendar_month.dart';
import '../controllers/calendar_providers.dart';
import '../widgets/month_grid.dart';
import '../widgets/month_navigator.dart';

/// Obligations laid out by date.
///
/// ## What this screen is for
///
/// One question the bills list cannot answer: **is there a heavy week coming.**
/// A list sorted by date tells you what is next; only a grid shows you that the
/// 15th to the 18th carries four bills and the rest of the month carries none.
///
/// ## Why there is no weekly or daily mode
///
/// The roadmap asked for three views. Two of them were dropped, deliberately.
///
/// A **weekly** view on a phone is a month grid with one row: it answers a
/// narrower question than the month does, and it cannot answer the one above at
/// all. It would cost a mode switch on every visit to show strictly less.
///
/// A **daily** view is "what is due on this date", which is a real need — and it
/// is the day detail that Sprint 46 opens from a tapped square, sitting under
/// the month rather than replacing it. Building it as a third mode now would
/// mean building it twice.
///
/// If a week ever earns its own view it will be because the squares cannot hold
/// what needs to go in them, and that is a Sprint 45 question.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<DateTime, List<BillWithStatus>>> byDate = ref.watch(
      billsByDueDateProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: AppContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenInset,
              AppSpacing.lg,
              AppSpacing.screenInset,
              AppSpacing.bottomNavClearance,
            ),
            child: switch (byDate) {
              // Matched before the loading case, not after. The grid is already
              // on screen and correct during a refresh, and replacing it with a
              // skeleton would flash the whole month away every time a bill is
              // written.
              AsyncValue<Map<DateTime, List<BillWithStatus>>>(
                value: final Map<DateTime, List<BillWithStatus>> value?,
              ) =>
                _Calendar(byDate: value),
              AsyncError<Map<DateTime, List<BillWithStatus>>>(
                error: final Object error,
              ) =>
                AppErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(billsProvider),
                ),
              _ => const _CalendarSkeleton(),
            },
          ),
        ),
      ),
    );
  }
}

class _Calendar extends ConsumerWidget {
  const _Calendar({required this.byDate});

  final Map<DateTime, List<BillWithStatus>> byDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarMonth month = ref.watch(calendarMonthProvider);

    // The database's today where there is one. An account with no bills has no
    // row to read it from, and there is nothing on screen for the device clock
    // to contradict.
    final DateTime today = CalendarMonth.dateOnly(
      ref.watch(calendarTodayProvider) ?? DateTime.now(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MonthNavigator(
          month: month,
          isOnToday: month.contains(today),
          onPrevious: () => ref.read(calendarMonthProvider.notifier).previous(),
          onNext: () => ref.read(calendarMonthProvider.notifier).next(),
          onToday: () =>
              ref.read(calendarMonthProvider.notifier).showToday(today),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Panel(
          child: MonthGrid(
            month: month,
            today: today,
            countFor: (DateTime day) => byDate[day]?.length ?? 0,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _MonthSummary(month: month, byDate: byDate),
      ],
    );
  }
}

/// A line under the grid saying what the month adds up to.
///
/// The grid shows the shape of a month; this says its size. Without it a user
/// looking at eleven marked squares has to add them up to answer the question
/// they came with.
///
/// Counts only what is still owed. A month whose bills are all settled reads as
/// nothing left to pay, which is the truth and the more useful half of it.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month, required this.byDate});

  final CalendarMonth month;
  final Map<DateTime, List<BillWithStatus>> byDate;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<BillWithStatus> inMonth = <BillWithStatus>[
      for (final MapEntry<DateTime, List<BillWithStatus>> entry
          in byDate.entries)
        if (month.contains(entry.key)) ...entry.value,
    ];

    if (inMonth.isEmpty) {
      return _Panel(
        child: Text(
          'Nothing is due this month.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }

    // Summed through Money rather than over minor units, so a mismatched
    // currency is a thrown error rather than a silently wrong total.
    final Money outstanding = inMonth.fold<Money>(
      Money.zero(inMonth.first.outstanding.currency),
      (Money sum, BillWithStatus item) => sum + item.outstanding,
    );

    return _Panel(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  inMonth.length == 1
                      ? '1 bill this month'
                      : '${inMonth.length} bills this month',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // A second line only when there is no figure to show.
                //
                // The label for the amount lives beside the amount, where a
                // label belongs — a lower-case fragment on the far side of the
                // row read as a typo rather than as a caption, and repeating it
                // here would say the same thing twice.
                if (outstanding.minorUnits == 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'All settled',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (outstanding.minorUnits > 0) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  'STILL TO PAY',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textTertiary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  outstanding.format(),
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The white sheet everything on this screen sits on.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.panel,
        border: colors.surfaceBorder,
      ),
      child: child,
    );
  }
}

/// The shape of the screen, before the bills arrive.
///
/// Sized to what actually lands so the page does not resize under the reader the
/// moment it loads.
class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            // The month heading, on the canvas rather than on a sheet — so it
            // takes the border colour, which is the one that shows there.
            AppSkeleton(width: 160, height: 24, color: colors.border),
            const Spacer(),
            AppSkeleton(
              width: 40,
              height: 40,
              borderRadius: AppRadii.round,
              color: colors.border,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppSkeleton(
              width: 40,
              height: 40,
              borderRadius: AppRadii.round,
              color: colors.border,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _Panel(
          child: Column(
            children: <Widget>[
              for (int week = 0; week < CalendarMonth.weekCount; week++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      for (int day = 0; day < CalendarMonth.daysPerWeek; day++)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: AppSkeleton(height: 20),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
