import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_actions_controller.dart';
import '../controllers/bill_detail_provider.dart';
import '../widgets/bill_detail_sheet.dart';
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
/// ## Still deliberately the plain version
///
/// Sprint 28 adds search, filters and sorting. This exists early because the edit
/// form needs something to tap, and a feature that cannot be reached cannot be
/// tested.
///
/// Archived bills are hidden by default, because that is what archiving means —
/// but the app bar can bring them back into the list, which is what keeps
/// archiving reversible rather than a delete wearing a friendlier word.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(billsProvider);
    final bool showArchived = ref.watch(showArchivedProvider);

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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    });

    return Scaffold(
      // Kept even though the reference gives each screen its own heading. The
      // shell's tabs do not label the screen they switched to, so without this
      // there is no confirmation of where a tap landed.
      appBar: AppBar(
        title: const Text('Bills'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(showArchivedProvider.notifier).toggle(),
            tooltip: showArchived ? 'Hide archived' : 'Show archived',
            isSelected: showArchived,
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
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
              _BillList(
                bills: list,
                showArchived: showArchived,
                onRefresh: () => _refresh(ref),
              ),
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

class _BillList extends ConsumerWidget {
  const _BillList({
    required this.bills,
    required this.showArchived,
    required this.onRefresh,
  });

  final List<BillWithStatus> bills;

  /// Only so the list can say so when the switch is on and there is nothing
  /// archived. Without it the toggle looks broken on the common case.
  final bool showArchived;

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_Group> groups = _group(bills);

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
          for (final _Group group in groups) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            _SectionHeading(label: group.label, count: group.bills.length),
            const SizedBox(height: AppSpacing.md),
            for (final BillWithStatus item in group.bills) ...<Widget>[
              BillSwipeActions(
                billKey: item.bill.id,
                onEdit: () => _openEditor(context, item),
                confirmDelete: () => _confirmDelete(context, ref, item),
                child: BillListTile(
                  item: item,
                  // A tap opens the detail drawer, not the editor. Looking at a
                  // bill and changing it were the same gesture before, and most
                  // taps are looks.
                  onTap: () => _openDetail(context, ref, item),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
            ],
          ],
          // The switch is on and nothing came back under it. Said out loud,
          // because a control that appears to do nothing reads as broken.
          if (showArchived &&
              !groups.any((_Group group) => group.label == _archivedLabel))
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.sectionGap),
              child: _Note('Nothing archived.'),
            ),
        ],
      ),
    );
  }

  /// Opens the edit form for one bill.
  static void _openEditor(BuildContext context, BillWithStatus item) =>
      context.pushNamed(
        AppRoutes.editBill.routeName,
        pathParameters: <String, String>{'id': item.bill.id},
      );

  /// Opens the detail drawer and acts on whatever the user chose there.
  ///
  /// The sheet returns an intent rather than doing the work itself: navigation and
  /// dialogs need a context that outlives the sheet, and a widget that pops itself
  /// and then keeps working is a widget that eventually uses a dead context.
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

    switch (action) {
      case BillDetailAction.edit:
        _openEditor(context, item);
      case BillDetailAction.archive:
        await _archive(context, ref, item);
      case BillDetailAction.restore:
        await ref
            .read(billActionsControllerProvider.notifier)
            .restore(item.bill.id);
      case BillDetailAction.delete:
        await _confirmDelete(context, ref, item);
    }
  }

  /// Archives, and offers the way back.
  ///
  /// Undo is honest here because archiving is reversible — it is one column. The
  /// delete path deliberately has no undo, and confirms instead.
  static Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    BillWithStatus item,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final BillActionsController controller = ref.read(
      billActionsControllerProvider.notifier,
    );

    if (!await controller.archive(item.bill.id)) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.bill.name} archived'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.restore(item.bill.id),
          ),
        ),
      );
  }

  /// Asks before deleting, and reports what it did.
  ///
  /// Returns whether the bill is gone, which is also what tells the swipe whether
  /// to let the row leave the list.
  static Future<bool> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BillWithStatus item,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    // A bill with payments cannot be deleted at all.
    //
    // `payments.bill_id` is `on delete restrict`, which the migration calls the
    // thing that makes "archive, do not delete" real. So the dialog used to
    // promise something Postgres refuses: it offered Delete, explained that the
    // payments would go too, and the request came back a foreign key violation.
    // Nobody had hit it because nothing could record a payment yet — this sprint
    // is where the client learns payments exist.
    if (item.paid.minorUnits > 0) {
      final bool archive = await showAppConfirmDialog(
        context: context,
        title: 'This bill cannot be deleted',
        message:
            'PayPaw has ${item.paid.format()} recorded against '
            '${item.bill.name}, and that history is the record of what you '
            'actually paid. Archive it instead to take it off the list.',
        confirmLabel: 'Archive',
      );

      if (archive && context.mounted) {
        await _archive(context, ref, item);
      }

      return false;
    }

    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete ${item.bill.name}?',
      // "Are you sure?" tells the reader nothing they did not already know.
      message:
          'This cannot be undone. Archive instead if you might want it back.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!confirmed) {
      return false;
    }

    final bool deleted = await ref
        .read(billActionsControllerProvider.notifier)
        .delete(item.bill.id);

    if (deleted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${item.bill.name} deleted')));
    }

    return deleted;
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
      if (archived.isNotEmpty) _Group(label: _archivedLabel, bills: archived),
    ];
  }
}

/// The heading archived bills sit under, and the marker the list checks for when
/// deciding whether the switch found anything.
const String _archivedLabel = 'Archived';

/// A quiet line of prose in the list, for the things that are not bills.
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: context.colors.textTertiary),
    );
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
