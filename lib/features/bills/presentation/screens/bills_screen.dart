import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_detail_provider.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/bills_summary_card.dart';

/// The list of bills.
///
/// ## The shape, and where it comes from
///
/// The reference design's screens are a stack of labelled sections on a grey
/// canvas: a headline panel, then a section label, then cards. This follows that
/// — a summary panel, then the bills under headings — rather than the bare list
/// the first version was, which answered no question at all.
///
/// **Grouped by urgency, not by date.** A flat list sorted by due date puts a bill
/// three days overdue below one due next week, and leaves the reader scanning for
/// red text. The groups do that scanning once: Overdue, Due soon, Upcoming,
/// Settled, in the order they need attention.
///
/// Empty groups are absent rather than shown empty. A heading reading "Overdue"
/// with nothing under it is a small daily untruth.
///
/// ## Still deliberately the plain version
///
/// Sprint 28 adds search, filters and sorting. This exists early because the edit
/// form needs something to tap, and a feature that cannot be reached cannot be
/// tested.
///
/// Archived bills are absent, because that is what archiving means. Sprint 25
/// gives them a way back.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(billsProvider);

    return Scaffold(
      // Kept even though the reference gives each screen its own heading. The
      // shell's tabs do not label the screen they switched to, so without this
      // there is no confirmation of where a tap landed.
      appBar: AppBar(title: const Text('Bills')),
      body: SafeArea(
        child: AppContentWidth(
          child: switch (bills) {
            AsyncLoading<List<BillWithStatus>>() => const Center(
              child: AppLoadingIndicator(),
            ),
            AsyncError<List<BillWithStatus>>(error: final Object error) =>
              AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(billsProvider),
              ),
            AsyncData<List<BillWithStatus>>(
              value: final List<BillWithStatus> list,
            )
                when list.isEmpty =>
              AppEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'No bills yet',
                message:
                    'Add the first one and PayPaw will remind you before it is '
                    'due.',
                actionLabel: 'Add bill',
                onAction: () => context.pushNamed(AppRoutes.addBill.routeName),
              ),
            AsyncData<List<BillWithStatus>>(
              value: final List<BillWithStatus> list,
            ) =>
              _BillList(bills: list, onRefresh: () => _refresh(ref)),
          },
        ),
      ),
      // No floating button. Adding a bill moved into the shell, beside the
      // navigation bar, so it works from every tab rather than only this one.
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(billsProvider);
    // Awaited so the pull-to-refresh spinner stays until the new rows arrive.
    // Without it the gesture completes instantly and the list appears not to
    // have refreshed.
    await ref.read(billsProvider.future);
  }
}

/// A group of bills under one heading.
@immutable
class _Group {
  const _Group({required this.label, required this.bills});

  final String label;
  final List<BillWithStatus> bills;
}

class _BillList extends StatelessWidget {
  const _BillList({required this.bills, required this.onRefresh});

  final List<BillWithStatus> bills;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          AppSpacing.lg,
          AppSpacing.screenInset,
          // Clears the floating navigation bar and the add button beside it.
          AppSpacing.bottomNavClearance + AppSpacing.xl,
        ),
        children: <Widget>[
          BillsSummaryCard(bills: bills),
          for (final _Group group in _group(bills)) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            _SectionHeading(label: group.label, count: group.bills.length),
            const SizedBox(height: AppSpacing.md),
            for (final BillWithStatus item in group.bills) ...<Widget>[
              BillListTile(
                item: item,
                // Straight to edit, for now. Sprint 26 puts a detail screen in
                // between, which is where a tap should land once there is more
                // to show than the six fields the form already holds.
                onTap: () => context.pushNamed(
                  AppRoutes.editBill.routeName,
                  pathParameters: <String, String>{'id': item.bill.id},
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
        ],
      ),
    );
  }

  /// Buckets the bills by how much attention they need.
  ///
  /// The order is fixed rather than data-driven: overdue first because it is
  /// already costing the user something, settled last because it is finished.
  ///
  /// A status this build does not recognise — one the view starts emitting before
  /// the app is updated — falls in with Upcoming rather than being dropped. A bill
  /// missing from the list is worse than a bill under the wrong heading.
  static List<_Group> _group(List<BillWithStatus> bills) {
    final List<BillWithStatus> overdue = <BillWithStatus>[];
    final List<BillWithStatus> dueSoon = <BillWithStatus>[];
    final List<BillWithStatus> upcoming = <BillWithStatus>[];
    final List<BillWithStatus> settled = <BillWithStatus>[];

    for (final BillWithStatus bill in bills) {
      switch (bill.status) {
        case BillStatus.overdue:
          overdue.add(bill);
        case BillStatus.dueSoon:
          dueSoon.add(bill);
        case BillStatus.paid:
          settled.add(bill);
        case BillStatus.upcoming:
        case BillStatus.partiallyPaid:
        case BillStatus.archived:
        case null:
          upcoming.add(bill);
      }
    }

    return <_Group>[
      if (overdue.isNotEmpty) _Group(label: 'Overdue', bills: overdue),
      if (dueSoon.isNotEmpty) _Group(label: 'Due soon', bills: dueSoon),
      if (upcoming.isNotEmpty) _Group(label: 'Upcoming', bills: upcoming),
      if (settled.isNotEmpty) _Group(label: 'Settled', bills: settled),
    ];
  }
}

/// A section label, as the reference draws them: small, quiet, with the count
/// beside it.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Text(
            // Small caps and letter-spaced, matching the summary card's label. A
            // heading that looks like body text is not a heading — and this reads
            // as more deliberate than a bold sentence while being quieter on the
            // page.
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadii.round,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 1,
              ),
              child: Text(
                '$count',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
