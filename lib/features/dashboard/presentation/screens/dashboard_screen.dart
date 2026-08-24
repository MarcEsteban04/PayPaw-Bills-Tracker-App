import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../bills/domain/entities/bill_outlook.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_totals.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_sheet.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import '../../../recurring/domain/entities/recurring_commitment.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_quick_actions.dart';

/// PayPaw's landing screen.
///
/// ## The shape, and where it comes from
///
/// The reference design's dashboard reads top to bottom as: who you are, one big
/// figure, the two things you can do about it, a strip of shortcuts, then the
/// detail. This follows that order, because it is the order the questions arrive
/// in — "how much do I owe" before "what is it made of".
///
/// ## What it is not
///
/// **Not the bills list with a different header.** Bills already answers "show me
/// everything, let me search it". This answers "what needs me today", so it shows
/// overdue in full and upcoming only [_upcomingLimit] deep, with a way through to
/// the list for the rest. Two tabs that show the same rows are one tab and a
/// wasted tap.
///
/// It also does not repeat the summary card. That card is the Bills screen's hero
/// and reusing it here would make the two screens open identically.
///
/// Sprints 35 to 38 deepen each block — the financial summary, the upcoming
/// grouping, the remaining quick actions, and the polish. This is the structure
/// they hang on.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// How many upcoming bills to show before deferring to the Bills tab.
  ///
  /// Three fits above the fold on a small phone alongside everything above it.
  /// A dashboard that scrolls for a screen and a half is a list.
  static const int _upcomingLimit = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(billsProvider);

    return Scaffold(
      body: SafeArea(
        child: AppContentWidth(
          child: switch (bills) {
            // The header is real before the bills are, so it is drawn either way
            // and only the blocks below it wait. A whole screen replaced by a
            // spinner on every launch is a launch that feels slow even when it
            // is not.
            AsyncLoading<List<BillWithStatus>>() => _Scaffold(
              ref: ref,
              children: const <Widget>[
                DashboardBlock(height: 132),
                SizedBox(height: AppSpacing.sectionGap),
                DashboardBlock(height: 88),
                SizedBox(height: AppSpacing.sectionGap),
                DashboardBlock(height: 160),
              ],
            ),
            AsyncError<List<BillWithStatus>>(error: final Object error) =>
              _Scaffold(
                ref: ref,
                children: <Widget>[
                  AppErrorState(
                    error: error,
                    onRetry: () => ref.invalidate(billsProvider),
                  ),
                ],
              ),
            AsyncData<List<BillWithStatus>>(
              value: final List<BillWithStatus> list,
            ) =>
              _Scaffold(ref: ref, children: _blocks(context, ref, list)),
          },
        ),
      ),
    );
  }

  /// Everything under the header, once the bills have arrived.
  List<Widget> _blocks(
    BuildContext context,
    WidgetRef ref,
    List<BillWithStatus> bills,
  ) {
    final BillTotals totals = BillTotals.of(bills);
    final List<BillWithStatus> overdue = _overdue(bills);
    final List<BillWithStatus> pending = _pending(bills);
    final List<BillWithStatus> upcoming = pending.take(_upcomingLimit).toList();

    // `today` from a bill row rather than the device clock — the same date the
    // statuses on this screen were computed against. Falls back only when there
    // are no bills, and then nothing below depends on it.
    final DateTime today = bills.firstOrNull?.today ?? DateTime.now();
    final BillOutlook outlook = BillOutlook.of(bills, today: today);

    return <Widget>[
      _Hero(totals: totals),
      const SizedBox(height: AppSpacing.sectionGap),

      DashboardQuickActions(actions: _actions(context)),

      if (outlook.hasAnything) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _StatRow(totals: totals, outlook: outlook, today: today),
      ],

      if (overdue.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        // Above upcoming, always. Something already late outranks something that
        // has not happened yet, and a dashboard that buries it under "what is
        // next" is answering the wrong question first.
        _Section(
          label: 'Needs paying now',
          count: overdue.length,
          bills: overdue,
          onOpen: (BillWithStatus item) => _openDetail(context, ref, item),
        ),
      ],

      const SizedBox(height: AppSpacing.sectionGap),
      if (bills.isEmpty)
        AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No bills yet',
          message:
              'Add the first one and PayPaw will keep track of it for you.',
          actionLabel: 'Add bill',
          onAction: () => context.pushNamed(AppRoutes.addBill.routeName),
        )
      else if (upcoming.isEmpty)
        // Bills exist, but none of them are waiting on anything. Said plainly
        // rather than shown as an empty heading, and it is genuinely good news.
        _AllClear(hasOverdue: overdue.isNotEmpty)
      else
        _Section(
          label: 'Coming up',
          count: upcoming.length,
          bills: upcoming,
          onOpen: (BillWithStatus item) => _openDetail(context, ref, item),
          // Only when something is actually being held back. "See all" over a
          // section already showing everything is a link to the screen you are
          // on.
          onSeeAll: pending.length > upcoming.length
              ? () => context.goNamed(AppRoutes.bills.routeName)
              : null,
        ),

      // The charts sit last on purpose. Everything above is actionable — a bill
      // to open, a button to press; these are context, and context that pushes
      // the actionable part below the fold has the screen the wrong way round.
      if (outlook.byCategory.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _CategoryBreakdown(outlook: outlook),
      ],
      if (outlook.hasAnything) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _MonthsAhead(outlook: outlook),
      ],
    ];
  }

  /// The actions that exist. See [DashboardQuickActions] on why the list is short.
  List<QuickAction> _actions(BuildContext context) => <QuickAction>[
    QuickAction(
      icon: Icons.add_rounded,
      label: 'Add bill',
      onPressed: () => context.pushNamed(AppRoutes.addBill.routeName),
    ),
    QuickAction(
      icon: Icons.receipt_long_rounded,
      label: 'All bills',
      onPressed: () => context.goNamed(AppRoutes.bills.routeName),
    ),
    QuickAction(
      icon: Icons.calendar_month_rounded,
      label: 'Calendar',
      onPressed: () => context.goNamed(AppRoutes.calendar.routeName),
    ),
  ];

  /// Everything late, soonest first — which for overdue means longest overdue.
  static List<BillWithStatus> _overdue(List<BillWithStatus> bills) =>
      bills.where((BillWithStatus b) => b.status == BillStatus.overdue).toList()
        ..sort(
          (BillWithStatus a, BillWithStatus b) =>
              a.bill.dueOn.compareTo(b.bill.dueOn),
        );

  /// Everything that still needs money and is not already late, soonest first.
  ///
  /// Returned whole rather than pre-trimmed, because the screen needs to know
  /// whether anything is being left out — "See all" on a section already showing
  /// everything is a link to what you are looking at.
  ///
  /// Archived bills are absent for the same reason they are absent everywhere:
  /// the user put them away.
  static List<BillWithStatus> _pending(List<BillWithStatus> bills) =>
      bills
          .where(
            (BillWithStatus b) =>
                !b.bill.isArchived &&
                b.status != BillStatus.overdue &&
                (b.status?.isOutstanding ?? false),
          )
          .toList()
        ..sort(
          (BillWithStatus a, BillWithStatus b) =>
              a.bill.dueOn.compareTo(b.bill.dueOn),
        );

  static Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    BillWithStatus item,
  ) async {
    final BillDetailAction? action = await showBillDetailSheet(
      context: context,
      item: item,
    );

    if (!context.mounted || action == null) {
      return;
    }

    // Only Edit is handled here. Archive and delete belong with the list that
    // owns them — a dashboard that can delete a bill is a dashboard that needs
    // every confirmation and undo the list already has, duplicated.
    if (action == BillDetailAction.edit) {
      // Not awaited: the caller does not care when the editor closes, and the
      // list it returns to is invalidated by the save itself.
      unawaited(
        context.pushNamed(
          AppRoutes.editBill.routeName,
          pathParameters: <String, String>{'id': item.bill.id},
        ),
      );
    }
  }
}

/// The header, then whatever the screen currently has to say.
class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.ref, required this.children});

  final WidgetRef ref;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        // Clears the floating navigation bar and the add button beside it.
        AppSpacing.bottomNavClearance + AppSpacing.xl,
      ),
      children: <Widget>[
        DashboardHeader(
          email: ref.watch(currentUserProvider).value?.email,
          now: DateTime.now(),
          onAvatarPressed: () => context.goNamed(AppRoutes.profile.routeName),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        ...children,
      ],
    );
  }
}

/// The figure the screen exists to show, and what it is made of.
///
/// Light, unlike the Bills screen's dark card. The two screens open on the same
/// number and would otherwise be indistinguishable at a glance — and this one is
/// followed by shortcuts, which need the green to themselves.
class _Hero extends StatelessWidget {
  const _Hero({required this.totals});

  final BillTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            // Centre is the default and is what this needs: the ring is taller
            // than the label and figure beside it, and top-aligning left a band
            // of empty card under the text that read as something missing.
            children: <Widget>[
              Expanded(child: _Figures(totals: totals)),
              // Only once there is a denominator. A ring at 0% of nothing is a
              // grey circle that invites the reader to work out what it means.
              if (totals.hasProgress) ...<Widget>[
                const SizedBox(width: AppSpacing.lg),
                ProgressRing(
                  fraction: totals.settledFraction,
                  caption: 'settled',
                ),
              ],
            ],
          ),
          if (totals.hasProgress) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${totals.settled.format()} of ${totals.billed.format()} paid off',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The label, the number, and the chips — the left half of the hero card.
class _Figures extends StatelessWidget {
  const _Figures({required this.totals});

  final BillTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TOTAL OUTSTANDING',
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Scaled down rather than wrapped or clipped. The ring takes 96 of the
        // card's ~320, so a seven-figure total at display size does not fit —
        // and a headline that wraps mid-number is unreadable.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            totals.outstanding.format(),
            maxLines: 1,
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}

/// Two figures that answer "when", which the headline cannot.
///
/// ₱5,500 outstanding is a different month depending on whether it all lands in
/// three weeks or spreads over six.
class _StatRow extends ConsumerWidget {
  const _StatRow({
    required this.totals,
    required this.outlook,
    required this.today,
  });

  final BillTotals totals;
  final BillOutlook outlook;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;

    // Null while the templates are still arriving, which is a moment. The other
    // three figures do not wait for it — a summary that blanks because one of
    // four numbers is late is a summary that is usually blank.
    final RecurringCommitment? commitment = switch (ref.watch(
      recurringBillsProvider,
    )) {
      AsyncData<List<RecurringBill>>(value: final List<RecurringBill> all) =>
        RecurringCommitment.of(all),
      _ => null,
    };

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DashboardCardTitle(title: 'The money'),
          const SizedBox(height: AppSpacing.lg),
          _FigureRow(
            left: SummaryFigure(
              label: 'Upcoming',
              value: totals.upcoming.format(),
              caption: '${outlook.dueThisMonth.format()} this month',
              tint: colors.dueSoon,
            ),
            right: SummaryFigure(
              label: 'Overdue',
              value: totals.overdue.format(),
              caption: totals.overdueCount == 1
                  ? '1 bill late'
                  : '${totals.overdueCount} bills late',
              tint: colors.overdue,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FigureRow(
            left: SummaryFigure(
              label: 'Paid',
              value: totals.settled.format(),
              caption: totals.hasProgress
                  ? '${(totals.settledFraction * 100).round()}% of everything'
                  : null,
              tint: colors.primary,
            ),
            right: SummaryFigure(
              label: 'Every month',
              // A dash rather than a zero while it loads. "₱0.00" is a claim,
              // and it is the wrong one for anyone who does have schedules.
              value: commitment?.perMonth.format() ?? '—',
              // The count, not the yearly figure. "₱192,000.00 a year, on
              // average" was truncated to "on ave…" in half the card's width,
              // and a caption that has to be guessed at is worse than a shorter
              // one — the number of schedules is also the more useful fact,
              // since it is what the reader would go and check.
              caption: switch (commitment) {
                null => 'counting…',
                final RecurringCommitment c when !c.hasAnything =>
                  'nothing repeats',
                final RecurringCommitment c when c.activeCount == 1 =>
                  'from 1 schedule',
                final RecurringCommitment c =>
                  'from ${c.activeCount} schedules',
              },
              tint: colors.info,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two figures sharing a row, each with half the width.
///
/// A plain `Row` of `Expanded`s rather than a `GridView`: two of them is not a
/// grid, and a scrollable inside a scrollable is a wrestling match.
class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: right),
      ],
    );
  }
}

/// Where the outstanding money is going.
class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown({required this.outlook});

  final BillOutlook outlook;

  /// The palette a slice falls back to when its category has no colour, and what
  /// "Other" and "Uncategorised" always use.
  ///
  /// Taken from the categories themselves wherever possible: a breakdown whose
  /// colours do not match the icons on the rows above it is a second colour
  /// language for the same things.
  static const List<int> _fallback = <int>[
    0xFF6366F1,
    0xFF0EA5E9,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF14B8A6,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];

    Category? lookup(String? id) =>
        categories.where((Category c) => c.id == id).firstOrNull;

    String nameOf(CategorySlice slice) {
      if (slice.isOther) {
        return 'Everything else';
      }

      return lookup(slice.categoryId)?.name ?? 'Uncategorised';
    }

    Color colorOf(CategorySlice slice, int index) {
      if (!slice.isOther) {
        final Color? own = CategoryIcons.parseColor(
          lookup(slice.categoryId)?.colorHex,
        );
        if (own != null) {
          return own;
        }
      }

      return Color(_fallback[index % _fallback.length]);
    }

    final List<CategorySlice> slices = outlook.byCategory;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DashboardCardTitle(
            title: 'Where it goes',
            subtitle: 'Outstanding by category',
          ),
          const SizedBox(height: AppSpacing.lg),
          StackedBar(
            slices: <BandSlice>[
              for (int i = 0; i < slices.length; i++)
                BandSlice(
                  share: slices[i].share,
                  color: colorOf(slices[i], i),
                  label: nameOf(slices[i]),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BreakdownLegend(
            rows: <LegendRow>[
              for (int i = 0; i < slices.length; i++)
                LegendRow(
                  color: colorOf(slices[i], i),
                  label: nameOf(slices[i]),
                  // Rounded, and never to zero: a slice that exists is at least
                  // "1%", because "0%" beside a real figure reads as a bug.
                  percent: '${math.max(1, (slices[i].share * 100).round())}%',
                  amount: slices[i].outstanding.format(),
                ),
            ],
          ),
          if (slices.length == 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              // One slice is a bar at full width, which says nothing. Naming that
              // is better than drawing a chart that looks broken.
              'Everything outstanding is in one category.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// What falls due over the next six months.
class _MonthsAhead extends StatelessWidget {
  const _MonthsAhead({required this.outlook});

  final BillOutlook outlook;

  @override
  Widget build(BuildContext context) {
    final Money busiest = outlook.busiestMonth;
    final DateTime thisMonth = outlook.byMonth.first.month;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DashboardCardTitle(
            title: 'The months ahead',
            subtitle: 'Busiest is ${busiest.format()}',
          ),
          const SizedBox(height: AppSpacing.lg),
          MonthlyDueChart(
            bars: <MonthBar>[
              for (final MonthlyDue month in outlook.byMonth)
                MonthBar(
                  label: DateFormat.MMM().format(month.month),
                  amount: month.outstanding.format(),
                  fraction: busiest.minorUnits <= 0
                      ? 0
                      : month.outstanding.minorUnits / busiest.minorUnits,
                  isCurrent: month.month == thisMonth,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled block of bills.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.count,
    required this.bills,
    required this.onOpen,
    this.onSeeAll,
  });

  final String label;
  final int count;
  final List<BillWithStatus> bills;
  final ValueChanged<BillWithStatus> onOpen;

  /// Shown only where there is more to see than is listed.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            if (onSeeAll case final VoidCallback seeAll)
              TextButton(
                onPressed: seeAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final BillWithStatus item in bills) ...<Widget>[
          BillListTile(item: item, onTap: () => onOpen(item)),
          if (item != bills.last) const SizedBox(height: AppSpacing.cardGap),
        ],
      ],
    );
  }
}

/// Bills exist, and none of them are waiting on anything.
class _AllClear extends StatelessWidget {
  const _AllClear({required this.hasOverdue});

  /// Changes what "clear" means: with something overdue above, this is only
  /// saying there is nothing *else*.
  final bool hasOverdue;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: AppRadii.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hasOverdue
                    ? 'Nothing else coming up. Clear the ones above and you are done.'
                    : 'Nothing coming up. Everything is settled.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
