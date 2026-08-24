import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_detail_provider.dart';
import '../widgets/bill_list_tile.dart';

/// The list of bills.
///
/// ## Deliberately the plain version
///
/// Sprint 28 is search, filters and sorting; this is the list without them. It
/// exists now because Sprint 24 built an edit form and the roadmap puts the list
/// four sprints later — so edit would have shipped with nothing to tap and no way
/// for anyone to try it. A feature that cannot be reached cannot be tested, and
/// an untested form is not a finished form.
///
/// Archived bills are absent, because that is what archiving means. Sprint 25
/// gives them a way back.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(billsProvider);

    return Scaffold(
      // Kept even though the list has its own heading in the reference design.
      // The shell's tabs do not label the screen they switched to, so without
      // this the user has no confirmation of where a tap landed.
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
                onAction: () => _openAdd(context),
              ),
            AsyncData<List<BillWithStatus>>(
              value: final List<BillWithStatus> list,
            ) =>
              _BillList(bills: list, onRefresh: () => _refresh(ref)),
          },
        ),
      ),
      floatingActionButton: Padding(
        // The navigation bar floats over content, so the button has to clear it
        // or it sits under the pill.
        padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
        child: FloatingActionButton.extended(
          onPressed: () => _openAdd(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add bill'),
        ),
      ),
    );
  }

  void _openAdd(BuildContext context) =>
      context.pushNamed(AppRoutes.addBill.routeName);

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(billsProvider);
    // Awaited so the pull-to-refresh spinner stays until the new rows arrive.
    // Without it the gesture completes instantly and the list appears not to
    // have refreshed.
    await ref.read(billsProvider.future);
  }
}

class _BillList extends StatelessWidget {
  const _BillList({required this.bills, required this.onRefresh});

  final List<BillWithStatus> bills;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          AppSpacing.lg,
          AppSpacing.screenInset,
          // Clears the floating navigation bar and the floating button above it.
          AppSpacing.bottomNavClearance + AppSpacing.huge,
        ),
        itemCount: bills.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
        itemBuilder: (BuildContext context, int index) {
          final BillWithStatus item = bills[index];

          return BillListTile(
            item: item,
            // Straight to edit, for now. Sprint 26 puts a detail screen in
            // between, which is where a tap should land once there is more to
            // show than the six fields the form already holds.
            onTap: () => context.pushNamed(
              AppRoutes.editBill.routeName,
              pathParameters: <String, String>{'id': item.bill.id},
            ),
          );
        },
      ),
    );
  }
}
