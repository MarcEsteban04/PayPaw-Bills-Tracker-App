import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_actions.dart';
import '../../../bills/presentation/widgets/bill_status_display.dart';
import '../../domain/entities/calendar_month.dart';
import '../controllers/calendar_providers.dart';
import '../widgets/calendar_day_bills.dart';
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
/// ## Why there is no weekly or daily *mode*
///
/// The roadmap asked for a month, a week and a day as three views. There is one
/// view here, and the day lives inside it.
///
/// A **weekly** mode on a phone is a month grid with one row: it answers a
/// narrower question than the month does, and it cannot answer the one above at
/// all. It would cost a mode switch on every visit to show strictly less. If a
/// week ever earns its own view it will be because the squares cannot hold what
/// needs to go in them, and that is a Sprint 45 question.
///
/// A **daily** view is "what is due on this date" — a real need, and answered
/// here by the list under the grid rather than by a mode that replaces it. That
/// list is the whole bottom half of the screen, so tapping a square narrows what
/// was already on show instead of navigating away from the month that gave it
/// context.
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
          // Scrolls, because the list under the grid is as long as the month is
          // busy. A fixed column fit until the day detail landed under it and
          // then overflowed by 146 pixels on a 2400px screen — which the widget
          // tests missed entirely, since they pump a 1200dp-tall view.
          child: SingleChildScrollView(
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

    final DateTime? selectedDay = ref.watch(selectedCalendarDayProvider);

    final List<BillWithStatus> inMonth = <BillWithStatus>[
      for (final MapEntry<DateTime, List<BillWithStatus>> entry
          in byDate.entries)
        if (month.contains(entry.key)) ...entry.value,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MonthNavigator(
          month: month,
          isOnToday: month.contains(today),
          onPrevious: () => ref.read(calendarMonthProvider.notifier).previous(),
          onNext: () => ref.read(calendarMonthProvider.notifier).next(),
          onToday: () => _showToday(ref, today),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Panel(
          child: MonthGrid(
            month: month,
            today: today,
            selectedDay: selectedDay,
            billsFor: (DateTime day) => byDate[day] ?? const <BillWithStatus>[],
            onDayTap: (DateTime day) => _pickDay(ref, month, day),
          ),
        ),
        // Left out entirely for a month with nothing in it. A panel reading
        // "0 bills · TOTAL ₱0.00" is three ways of saying what the line below
        // already says in words.
        if (inMonth.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _MonthSummary(inMonth: inMonth),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        CalendarDayBills(
          month: month,
          selectedDay: selectedDay,
          byDate: byDate,
          onBillTap: (BillWithStatus item) => _openBill(context, ref, item),
        ),
      ],
    );
  }

  /// Picks a day, bringing its month into view first if it is one of the dimmed
  /// ones at either end.
  ///
  /// Without that step, tapping the 30th of the previous month would select a
  /// date the grid was about to stop showing, and the panel below would name a
  /// day nothing on screen pointed at.
  static void _pickDay(WidgetRef ref, CalendarMonth month, DateTime day) {
    if (!month.contains(day)) {
      ref.read(calendarMonthProvider.notifier).showMonthOf(day);
    }

    ref.read(selectedCalendarDayProvider.notifier).toggle(day);
  }

  /// Back to today's month, with today picked.
  ///
  /// Selecting it rather than only scrolling to it: the button says "Today", and
  /// landing on the month with nothing chosen answers a vaguer question than the
  /// one asked.
  static void _showToday(WidgetRef ref, DateTime today) {
    ref.read(calendarMonthProvider.notifier).showMonthOf(today);
    ref.read(selectedCalendarDayProvider.notifier).select(today);
  }

  /// The same drawer the bills list opens, and the same actions inside it.
  ///
  /// Shared rather than reimplemented — see [openBillDetail]. A second copy of
  /// the switch here would be a second place for "delete this bill" to fall
  /// behind, and the half that falls behind is always the warning.
  ///
  /// Nothing is done with the result: recording a payment, archiving or deleting
  /// all invalidate the bills, and this screen is built from them — so the grid,
  /// the total and the list below all follow without this knowing what happened.
  static Future<void> _openBill(
    BuildContext context,
    WidgetRef ref,
    BillWithStatus item,
  ) => openBillDetail(context: context, ref: ref, item: item);
}

/// A line under the grid saying what the month adds up to.
///
/// The grid shows the shape of a month; this says its size. Without it a user
/// looking at eleven marked squares has to add them up to answer the question
/// they came with.
///
/// ## Two figures, and the total is the one always shown
///
/// **The total** is what the month costs, whether or not any of it has been
/// paid — the number somebody is budgeting against, and the one that does not
/// change under them as they settle things.
///
/// **Still to pay** is what is left of it, and appears only when it differs
/// from the total. Showing both when they are equal is the same number twice
/// with two labels, which makes a reader stop and work out which is which.
///
/// Counts only the days that belong to the month. The grid shows the days
/// either side and counting those would make the total disagree with the
/// heading above it.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.inMonth});

  /// The bills falling in the month on screen. Never empty — the caller leaves
  /// this out entirely for a month with nothing in it, so that the panel below
  /// is the one place that says so.
  final List<BillWithStatus> inMonth;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Summed through Money rather than over minor units, so a mismatched
    // currency is a thrown error rather than a silently wrong total.
    final String currency = inMonth.first.bill.amount.currency;

    final Money total = inMonth.fold<Money>(
      Money.zero(currency),
      (Money sum, BillWithStatus item) => sum + item.bill.amount,
    );
    final Money outstanding = inMonth.fold<Money>(
      Money.zero(currency),
      (Money sum, BillWithStatus item) => sum + item.outstanding,
    );

    final bool isSettled = outstanding.minorUnits == 0;

    return _Panel(
      footer: _StatusBreakdown(inMonth: inMonth),
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  isSettled
                      ? 'All settled'
                      : '${outstanding.format()} still to pay',
                  style: textTheme.bodySmall?.copyWith(
                    color: isSettled ? colors.paidText : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'TOTAL',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                total.format(),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The white sheet everything on this screen sits on.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.footer});

  final Widget child;

  /// A second row, under a hairline. For content that belongs to the panel but
  /// answers a different question from the figures above it.
  final Widget? footer;

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
      child: footer == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                child,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(height: 1, color: colors.border),
                ),
                footer!,
              ],
            ),
    );
  }
}

/// How the month's bills are doing, counted by state.
///
/// ## It is the legend as well as the count
///
/// The squares above are coloured by the loudest bill on each day, and colour on
/// its own teaches nobody what it means. These chips name every colour that is
/// actually on the grid and say how many days' worth of it there is — so the key
/// is not a separate row of decoration nobody reads, it is the answer to "what
/// is this month made of".
///
/// Only the states present appear. A month with nothing overdue should not have
/// a chip reading "0 overdue"; that is a reassurance the absence already gives.
class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.inMonth});

  final List<BillWithStatus> inMonth;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Map<BillStatus?, int> counts = <BillStatus?, int>{};
    for (final BillWithStatus item in inMonth) {
      counts[item.status] = (counts[item.status] ?? 0) + 1;
    }

    // Loudest first, so the thing worth acting on is the first chip read.
    final List<BillStatus?> ordered = counts.keys.toList()
      ..sort(
        (BillStatus? a, BillStatus? b) =>
            (a?.urgency ?? 99).compareTo(b?.urgency ?? 99),
      );

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final BillStatus? status in ordered)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.statusTint(BillStatusDisplay.tone(status)),
              borderRadius: AppRadii.round,
            ),
            child: Text(
              '${counts[status]} ${BillStatusDisplay.label(status).toLowerCase()}',
              style: textTheme.labelSmall?.copyWith(
                color: colors.statusText(BillStatusDisplay.tone(status)),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
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
