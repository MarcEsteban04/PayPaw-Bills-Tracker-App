import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../domain/entities/debt.dart';
import '../controllers/debt_write_controller.dart';
import '../widgets/debt_form.dart';

/// Records utang.
///
/// A full screen rather than a sheet, for the reason `AddBillScreen` gives: the
/// form opens date pickers and a keyboard leaves a bottom sheet almost no room.
/// Above the shell, so the navigation bar does not sit under a form.
///
/// Thin on purpose. Everything the form does lives in [DebtForm], which the edit
/// screen uses too.
class AddDebtScreen extends ConsumerWidget {
  const AddDebtScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DebtWriteState state = ref.watch(debtWriteControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add utang'),
        leading: IconButton(
          onPressed: state.isSaving ? null : () => closeDebtForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: DebtForm(
          submitLabel: 'Save',
          isSaving: state.isSaving,
          errorMessage: state.errorMessage,
          onSubmit: (DebtFormValues values) => _save(context, ref, values),
        ),
      ),
    );
  }

  /// Writes it, then leaves.
  ///
  /// Awaited rather than watched, because the answer this screen needs — did
  /// this save land — is exactly what the call returns. A null is a failure the
  /// controller has already put on screen as an inline message.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    DebtFormValues values,
  ) async {
    final Debt? saved = await ref
        .read(debtWriteControllerProvider.notifier)
        .create(values.toDraft());

    if (saved == null || !context.mounted) {
      return;
    }

    // Raised before the screen closes, and it survives that: the toast lives in
    // the root overlay rather than in this route's messenger.
    showAppToast(
      context,
      message: '${saved.counterpartyName} saved',
      tone: AppToastTone.success,
    );

    closeDebtForm(context);
  }
}

/// Leaves a debt form.
///
/// `pop` when there is a stack, because the form is pushed over whatever the
/// user was looking at. The named fallback covers being opened directly, which
/// a deep link or a test can do.
void closeDebtForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(AppRoutes.debts.routeName);
  }
}
