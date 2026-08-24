import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_totals.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_sheet.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';
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

    return <Widget>[
      _Hero(totals: totals),
      const SizedBox(height: AppSpacing.sectionGap),

      DashboardQuickActions(actions: _actions(context)),

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
        Text(
          totals.outstanding.format(),
          style: textTheme.displayMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            if (totals.overdueCount > 0)
              _Stat(
                label: '${totals.overdueCount} overdue',
                amount: totals.overdue.format(),
                foreground: colors.overdueText,
                background: colors.overdueTint,
              ),
            if (totals.dueSoonCount > 0)
              _Stat(
                label: '${totals.dueSoonCount} due soon',
                amount: totals.dueSoon.format(),
                foreground: colors.dueSoonText,
                background: colors.dueSoonTint,
              ),
            // Neither chip is worth drawing when nothing is pressing, and an
            // empty row under the figure would read as something failing to load.
            if (!totals.needsAttention)
              _Stat(
                label: totals.unpaidCount > 0 ? 'Nothing due yet' : 'All clear',
                amount: null,
                foreground: colors.primaryText,
                background: colors.primarySoft,
              ),
          ],
        ),
      ],
    );
  }
}

/// A small figure beside the headline — the reference's accent chips.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.amount,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String? amount;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (amount case final String value) ...<Widget>[
              Text(
                value,
                style: textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: amount == null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
