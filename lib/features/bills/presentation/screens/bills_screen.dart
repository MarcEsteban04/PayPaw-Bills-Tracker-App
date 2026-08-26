import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_filter.dart';
import '../../domain/entities/bill_sort.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_actions_controller.dart';
import '../controllers/bill_detail_provider.dart';
import '../controllers/bill_filter_controller.dart';
import '../widgets/bill_detail_actions.dart';
import '../widgets/bill_filter_bar.dart';
import '../widgets/bill_filter_sheets.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/bill_swipe_actions.dart';
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
/// ## Searching and filtering
///
/// Both live in [BillFilterBar] above the summary, and both are applied on the
/// client — see `BillFilter`. The archive switch that used to sit in the app bar
/// is gone: "show me the ones I put away" is a status filter, and having it in two
/// places was two controls for one question.
///
/// The groups only survive the default order. They *are* a due-date sort, so
/// asking for largest-first and getting the largest overdue bill followed by the
/// largest upcoming one answers a question nobody asked. Any other sort flattens
/// the list.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The filtered list, not the raw one. The summary card is fed the same
    // narrowed list on purpose: a total that ignores the filter would answer a
    // question the screen is no longer asking.
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(
      filteredBillsProvider,
    );
    final BillFilter filter = ref.watch(billFilterProvider);

    // Failures from archive, restore and delete.
    //
    // The controller has recorded these since it was written and nothing ever
    // read them, so a delete that the server refused looked exactly like a delete
    // that worked: the dialog closed, the sheet closed, and the row was still
    // there with no explanation. Silence is the worst possible report on a
    // destructive action.
    //
    // Listened for here rather than in the sheet or the dialog, because both of
    // those are gone by the time the request fails.
    ref.listen<BillActionState>(billActionsControllerProvider, (
      BillActionState? previous,
      BillActionState next,
    ) {
      // Compared against the previous message rather than cleared afterwards.
      // Clearing would mean writing to a provider from inside its own listener,
      // and it is not needed: every action clears the error before it starts, so
      // the same failure twice still arrives here as null then message.
      if (next.errorMessage case final String message
          when message != previous?.errorMessage) {
        showAppToast(context, message: message, tone: AppToastTone.error);
      }
    });

    return Scaffold(
      // Kept even though the reference gives each screen its own heading. The
      // shell's tabs do not label the screen they switched to, so without this
      // there is no confirmation of where a tap landed.
      appBar: AppBar(
        title: const Text('Bills'),
        actions: <Widget>[
          // Subscriptions, from the screen its charges land on.
          //
          // The dashboard tile was the only way in, and somebody who lives on
          // this tab could go a long time without meeting it. Here because the
          // adjacency is already true: a subscription generates the bills in the
          // list below, and every one of them carries the repeat marker.
          //
          // Leftmost, and furthest from the filled circle on the right. That one
          // creates, and keeping the "leave this screen" control away from it
          // stops a thumb reaching for one and finding the other.
          IconButton(
            onPressed: () =>
                context.pushNamed(AppRoutes.subscriptions.routeName),
            tooltip: 'Subscriptions',
            icon: const Icon(Icons.subscriptions_outlined),
          ),
          // Only when there is something to clear. A permanently visible
          // "Clear filters" on an unfiltered screen is a button that does
          // nothing, and the pill row already shows what is applied.
          if (filter.isNarrowed)
            TextButton(
              onPressed: () => ref.read(billFilterProvider.notifier).clear(),
              child: Text('Clear (${filter.narrowCount})'),
            ),
          // Sort lives here rather than among the filter pills. As a fifth pill
          // it sat off the end of a 392dp row, reachable only by scrolling to
          // something the user could not see — and it never belonged in that row
          // anyway, since reordering a list narrows nothing.
          IconButton(
            onPressed: () => _pickSort(context, ref, filter.sort),
            tooltip: 'Sort: ${filter.sort.label}',
            isSelected: !filter.sort.isDefault,
            icon: const Icon(Icons.swap_vert_rounded),
          ),
          // Adding a bill lives here now, not on the navigation bar.
          //
          // A filled circle rather than a third bare icon: the two beside it
          // narrow what is already on screen, and this one makes something new.
          // Given the same weight they would read as three variations of the
          // same kind of control.
          //
          // Pushed, not a branch, so the form covers the navigation and comes
          // back to this list.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: _AddBillButton(
              onPressed: () => context.pushNamed(AppRoutes.addBill.routeName),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: AppContentWidth(child: _results(context, ref, bills, filter)),
      ),
      // No floating button. Adding a bill is the circle in the header above,
      // where it sits over the list it adds to.
    );
  }

  static Future<void> _pickSort(
    BuildContext context,
    WidgetRef ref,
    BillSort current,
  ) async {
    final BillSort? chosen = await showFilterSingleSelect<BillSort>(
      context: context,
      title: 'Sort by',
      options: BillSort.values
          .map(
            (BillSort sort) =>
                FilterOption<BillSort>(value: sort, label: sort.label),
          )
          .toList(),
      selected: current,
    );

    if (chosen != null) {
      ref.read(billFilterProvider.notifier).setSort(chosen);
    }
  }

  /// Today in the user's zone, from any row the server returned.
  ///
  /// Read from the *unfiltered* rows, which are still there when the filtered
  /// ones are not — so the date pickers keep working on a filter that matches
  /// nothing. Null only when the user has no bills at all.
  static DateTime? _today(WidgetRef ref) =>
      ref.watch(billsProvider).value?.firstOrNull?.today;

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BillWithStatus>> bills,
    BillFilter filter,
  ) {
    final DateTime? today = _today(ref);

    // Rows we already have outrank a load in flight.
    //
    // This matched `AsyncLoading` first, which is right for the first fetch and
    // wrong for every refresh after it: a refresh is *also* `AsyncLoading`, with
    // the previous rows still attached. So pulling to refresh replaced the list
    // with a centred spinner — a second spinner, under the pull gesture's own —
    // and recording a payment made the whole list vanish and come back.
    return switch (bills) {
      // No bills at all. The whole screen is the empty state: there is no total
      // worth showing and nothing to search, so a summary card reading ₱0.00
      // above an empty search box would be furniture around an apology.
      //
      // Keyed off `today` rather than the filtered list, because that comes from
      // the unfiltered rows — a filter matching nothing is the *other* case.
      AsyncValue<List<BillWithStatus>>(hasValue: true) when today == null =>
        AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No bills yet',
          message:
              'Add the first one and PayPaw will remind you before it is due.',
          actionLabel: 'Add bill',
          onAction: () => context.pushNamed(AppRoutes.addBill.routeName),
        ),
      AsyncValue<List<BillWithStatus>>(
        value: final List<BillWithStatus> list?,
      ) =>
        _BillList(
          bills: list,
          sort: filter.sort,
          // Non-null: the arm above catches the only case where it is not.
          today: today!,
          isNarrowed: filter.isNarrowed,
          onClearFilters: () => ref.read(billFilterProvider.notifier).clear(),
          onRefresh: () => _refresh(ref),
        ),
      // Only reached with nothing to fall back on. A refresh that fails leaves
      // the rows in place; they are still true as of the last fetch, and the
      // gesture is how the user asks again.
      AsyncError<List<BillWithStatus>>(error: final Object error) =>
        AppErrorState(
          error: error,
          onRetry: () => ref.invalidate(billsProvider),
        ),
      _ => const Center(child: AppLoadingIndicator()),
    };
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

/// Records a bill, from the top of the list it will join.
///
/// This used to float beside the bottom navigation bar, where it worked from
/// every tab. It reads better here: the action sits above the thing it adds to,
/// and the navigation bar is left saying only where you can go.
///
/// A filled circle, not a bare `IconButton`. The two controls beside it narrow
/// what is already on screen; this one makes something new, and at equal weight
/// all three would read as variations of the same kind of control.
class _AddBillButton extends StatelessWidget {
  const _AddBillButton({required this.onPressed});

  final VoidCallback onPressed;

  /// Smaller than a bare icon button's 48dp target, but the `Semantics` and the
  /// surrounding padding keep the touchable area at the minimum.
  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      button: true,
      label: 'Add bill',
      child: Tooltip(
        message: 'Add bill',
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Material(
              color: colors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: colors.textOnPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BillList extends ConsumerWidget {
  const _BillList({
    required this.bills,
    required this.sort,
    required this.today,
    required this.isNarrowed,
    required this.onClearFilters,
    required this.onRefresh,
  });

  final List<BillWithStatus> bills;

  /// Decides whether the urgency headings appear at all. See the class doc on
  /// [BillsScreen]: the groups are a due-date order, so they cannot coexist with
  /// a different one.
  final BillSort sort;

  /// Today in the user's zone, for the filter bar's pickers and preview.
  final DateTime today;

  /// Whether anything is narrowing [bills], which is what tells an empty result
  /// apart from an empty account.
  final bool isNarrowed;

  final VoidCallback onClearFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Already filtered and already sorted by `BillFilter.apply`. Grouping
    // preserves the order it was handed within each bucket.
    final List<_Group> groups = sort.isDefault
        ? _group(bills)
        : <_Group>[_Group(label: sort.label, bills: bills)];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // Always scrollable, so pull-to-refresh still works when a filter has
        // left the list too short to scroll.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          AppSpacing.lg,
          AppSpacing.screenInset,
          // Clears the floating navigation bar and the add button beside it.
          AppSpacing.bottomNavClearance + AppSpacing.xl,
        ),
        children: <Widget>[
          BillsSummaryCard(bills: bills),
          const SizedBox(height: AppSpacing.lg),

          // Under the card, where the answer is: the total says how much is
          // owed, and the controls under it are for narrowing that down.
          //
          // Inside the list rather than pinned above it, which means it scrolls
          // away — and means the list has to render even when nothing matches,
          // or the box being typed into would disappear on the keystroke that
          // narrowed too far. That is why the no-results state below is a row in
          // this list rather than a screen replacing it.
          BillFilterBar(today: today),

          if (groups.isEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            AppEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'No bills match',
              message:
                  'Nothing here fits what you are looking for. Widen the '
                  'filters or clear them to see everything again.',
              actionLabel: isNarrowed ? 'Clear filters' : null,
              onAction: isNarrowed ? onClearFilters : null,
            ),
          ],

          for (final _Group group in groups) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            _SectionHeading(label: group.label, count: group.bills.length),
            const SizedBox(height: AppSpacing.md),
            for (final BillWithStatus item in group.bills) ...<Widget>[
              BillSwipeActions(
                billKey: item.bill.id,
                onEdit: () => openBillEditor(context, item),
                confirmDelete: () =>
                    confirmDeleteBill(context: context, ref: ref, item: item),
                child: BillListTile(
                  item: item,
                  // A tap opens the detail drawer, not the editor. Looking at a
                  // bill and changing it were the same gesture before, and most
                  // taps are looks.
                  onTap: () =>
                      openBillDetail(context: context, ref: ref, item: item),
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
  ///
  /// Archived goes last and on its own. It used to fall in with Upcoming, which
  /// was harmless only for as long as archived bills never reached this list — a
  /// bill the user has put away announcing itself as upcoming is the opposite of
  /// what archiving was for.
  static List<_Group> _group(List<BillWithStatus> bills) {
    final List<BillWithStatus> overdue = <BillWithStatus>[];
    final List<BillWithStatus> dueToday = <BillWithStatus>[];
    final List<BillWithStatus> dueSoon = <BillWithStatus>[];
    final List<BillWithStatus> upcoming = <BillWithStatus>[];
    final List<BillWithStatus> settled = <BillWithStatus>[];
    final List<BillWithStatus> archived = <BillWithStatus>[];

    for (final BillWithStatus bill in bills) {
      // The column, not the status. A bill archived while it was overdue keeps
      // reporting `overdue` from the view, and it belongs here regardless of what
      // it was doing when it was put away.
      if (bill.bill.archivedAt != null) {
        archived.add(bill);
        continue;
      }

      switch (bill.status) {
        case BillStatus.overdue:
          overdue.add(bill);
        case BillStatus.dueToday:
          dueToday.add(bill);
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
      // Its own heading rather than folded into Due soon. Today is the last day
      // a bill can be paid on time, and a group that mixes it with Friday's makes
      // the reader check every date to find that out.
      if (dueToday.isNotEmpty) _Group(label: 'Due today', bills: dueToday),
      if (dueSoon.isNotEmpty) _Group(label: 'Due soon', bills: dueSoon),
      if (upcoming.isNotEmpty) _Group(label: 'Upcoming', bills: upcoming),
      if (settled.isNotEmpty) _Group(label: 'Settled', bills: settled),
      if (archived.isNotEmpty) _Group(label: _archivedLabel, bills: archived),
    ];
  }
}

/// The heading archived bills sit under, and the marker the list checks for when
/// deciding whether the switch found anything.
const String _archivedLabel = 'Archived';

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
