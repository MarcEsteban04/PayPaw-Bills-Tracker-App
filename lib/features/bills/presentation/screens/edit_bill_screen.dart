import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../domain/entities/bill_with_status.dart';
import '../controllers/bill_detail_provider.dart';
import '../controllers/bill_write_controller.dart';
import '../widgets/bill_form.dart';
import 'add_bill_screen.dart';

/// Changes a bill that exists.
///
/// ## Why it fetches rather than being handed the bill
///
/// The route carries an id, not an object. That is what makes the screen
/// reachable by a deep link and by a back-button restore, and it means the form
/// opens on what the database currently holds rather than on whatever a list
/// happened to be showing — which may be minutes stale, or edited on another
/// device.
///
/// The cost is a load state on a screen that often has the data already. Worth
/// paying: an edit form prefilled from stale values silently writes those values
/// back, and overwriting a change you never saw is the worst failure this screen
/// has.
class EditBillScreen extends ConsumerWidget {
  const EditBillScreen({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BillWithStatus?> bill = ref.watch(
      billDetailProvider(billId),
    );
    final BillWriteState state = ref.watch(billWriteControllerProvider);

    ref.listen<BillWriteState>(billWriteControllerProvider, (
      BillWriteState? previous,
      BillWriteState next,
    ) {
      if (previous?.savedName == null && next.savedName != null) {
        _onSaved(context, ref, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit bill'),
        leading: IconButton(
          onPressed: state.isSaving ? null : () => closeBillForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: switch (bill) {
          AsyncLoading<BillWithStatus?>() => const Center(
            child: AppLoadingIndicator(),
          ),
          AsyncError<BillWithStatus?>(error: final Object error) =>
            AppErrorState(
              error: error,
              onRetry: () => ref.invalidate(billDetailProvider(billId)),
            ),
          // A null is a bill that is not there *for this user* — deleted, or
          // someone else's. The two are the same answer under RLS and have to
          // stay the same answer, so the message says neither.
          AsyncData<BillWithStatus?>(value: null) => const AppStateMessage(
            icon: Icons.search_off_rounded,
            title: 'Bill not found',
            message:
                'This bill is no longer here. It may have been deleted from '
                'another device.',
          ),
          AsyncData<BillWithStatus?>(value: final BillWithStatus item) =>
            BillForm(
              // Keyed by the bill, so arriving at a different one rebuilds the
              // fields instead of showing the previous bill's values in them.
              key: ValueKey<String>(item.bill.id),
              submitLabel: 'Save changes',
              // See BillForm.showRecurrence: editing cannot write one yet.
              showRecurrence: false,
              initial: BillFormValues.of(item.bill),
              isSaving: state.isSaving,
              errorMessage: state.errorMessage,
              onSubmit: (BillFormValues values) => ref
                  .read(billWriteControllerProvider.notifier)
                  .update(item.bill, values),
            ),
        },
      ),
    );
  }

  void _onSaved(BuildContext context, WidgetRef ref, BillWriteState state) {
    // The row this screen read is now out of date, and so is any list showing
    // it. Invalidating rather than patching a cache: the view recomputes the
    // status and the totals, and only the database knows what those are now.
    ref.invalidate(billDetailProvider(billId));
    ref.invalidate(billsProvider);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${state.savedName!} updated')));

    closeBillForm(context);
  }
}
