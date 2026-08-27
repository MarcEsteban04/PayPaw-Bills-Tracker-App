import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_with_status.dart';
import '../controllers/debt_providers.dart';
import '../controllers/debt_write_controller.dart';
import '../widgets/debt_form.dart';
import 'add_debt_screen.dart';

/// Changes utang that exists.
///
/// The route carries an id, not an object — the same choice `EditBillScreen`
/// makes. It is what makes the screen reachable by a deep link, and the form
/// opens on what the database currently holds rather than on whatever a list
/// happened to be showing.
class EditDebtScreen extends ConsumerWidget {
  const EditDebtScreen({required this.debtId, super.key});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DebtWithStatus?> debt = ref.watch(debtProvider(debtId));
    final DebtWriteState state = ref.watch(debtWriteControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit utang'),
        leading: IconButton(
          onPressed: state.isSaving ? null : () => closeDebtForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: switch (debt) {
          AsyncLoading<DebtWithStatus?>() => const Center(
            child: AppLoadingIndicator(),
          ),
          AsyncError<DebtWithStatus?>(error: final Object error) =>
            AppErrorState(
              error: error,
              onRetry: () => ref.invalidate(debtProvider(debtId)),
            ),
          // A null is a debt that is not there *for this user* — deleted, or
          // someone else's. The two are the same answer under RLS and have to
          // stay the same answer, so the message says neither.
          AsyncData<DebtWithStatus?>(value: null) => const AppStateMessage(
            icon: Icons.search_off_rounded,
            title: 'Not found',
            message:
                'This is no longer here. It may have been deleted from another '
                'device.',
          ),
          AsyncData<DebtWithStatus?>(value: final DebtWithStatus found) =>
            DebtForm(
              // Keyed by the debt, so arriving at a different one rebuilds the
              // fields instead of showing the previous one's values.
              key: ValueKey<String>(found.id),
              submitLabel: 'Save changes',
              initial: DebtFormValues.of(found.debt),
              isSaving: state.isSaving,
              errorMessage: state.errorMessage,
              onSubmit: (DebtFormValues values) =>
                  _save(context, ref, found.debt, values),
            ),
        },
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Debt original,
    DebtFormValues values,
  ) async {
    final Debt edited = original
        .copyWith(
          direction: values.direction,
          counterpartyName: values.counterpartyName.trim(),
          counterpartyContact: values.contact,
          principal: values.money,
          incurredOn: values.incurredOn,
          dueOn: values.dueOn,
          notes: values.trimmedNotes,
        )
        // `copyWith` reads a null as "leave it alone", so clearing a field takes
        // saying so. Without this, removing an agreed date or a contact would
        // silently keep the old one.
        .clearing(
          contact: values.contact == null,
          dueOn: values.dueOn == null,
          notes: values.trimmedNotes == null,
        );

    final Debt? saved = await ref
        .read(debtWriteControllerProvider.notifier)
        .update(edited);

    if (saved == null || !context.mounted) {
      return;
    }

    // The row this screen read is now out of date. Invalidated rather than
    // patched: the view recomputes the totals, and only the database knows what
    // they are for a row it has just written.
    ref.invalidate(debtProvider(debtId));

    showAppToast(
      context,
      message: '${saved.counterpartyName} updated',
      tone: AppToastTone.success,
    );

    closeDebtForm(context);
  }
}
