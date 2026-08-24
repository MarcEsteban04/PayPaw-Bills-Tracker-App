import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../controllers/bill_detail_provider.dart';
import '../controllers/bill_write_controller.dart';
import '../widgets/bill_form.dart';

/// Records a bill.
///
/// A full screen rather than a sheet: six fields, one of which opens a date
/// picker and another a category sheet. A sheet that spawns a sheet is a stack
/// the user cannot see the shape of, and on a small phone the keyboard leaves a
/// bottom sheet almost no room. Above the shell, so the navigation bar does not
/// sit under a form.
///
/// Thin on purpose. Everything the form does lives in [BillForm], which the edit
/// screen uses too; this file supplies the title, the button's word, and what
/// happens on success.
class AddBillScreen extends ConsumerWidget {
  const AddBillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BillWriteState state = ref.watch(billWriteControllerProvider);

    ref.listen<BillWriteState>(billWriteControllerProvider, (
      BillWriteState? previous,
      BillWriteState next,
    ) {
      // Navigating during a build is an error, so leaving happens here.
      if (previous?.savedName == null && next.savedName != null) {
        _onSaved(context, ref, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add bill'),
        leading: IconButton(
          onPressed: state.isSaving ? null : () => closeBillForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: BillForm(
          submitLabel: 'Save bill',
          isSaving: state.isSaving,
          errorMessage: state.errorMessage,
          onSubmit: (BillFormValues values) =>
              ref.read(billWriteControllerProvider.notifier).create(values),
        ),
      ),
    );
  }

  void _onSaved(BuildContext context, WidgetRef ref, BillWriteState state) {
    // The list is now out of date. Invalidated rather than patched: the view
    // computes the status and the totals, and only the database knows what they
    // are for a row it has just seen for the first time.
    ref.invalidate(billsProvider);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${state.savedName!} saved')));

    closeBillForm(context);
  }
}

/// Leaves a bill form.
///
/// `pop` when there is a stack, because the form is pushed over whatever the user
/// was looking at and they should return to it. The named fallback covers being
/// opened directly, which a deep link or a test can do.
void closeBillForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(AppRoutes.bills.routeName);
  }
}
