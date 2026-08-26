import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_providers.dart';
import '../controllers/subscription_write_controller.dart';
import '../widgets/subscription_form.dart';
import 'add_subscription_screen.dart';

/// Changes a subscription that exists.
///
/// ## Why it fetches rather than being handed the subscription
///
/// The route carries an id, not an object — the same choice `EditBillScreen`
/// makes, for the same reason. It is what makes the screen reachable by a deep
/// link and by a back-button restore, and the form opens on what the database
/// currently holds rather than on whatever the list happened to be showing.
///
/// The cost is a load state on a screen that usually has the data already. Worth
/// paying: a form prefilled from stale values silently writes those values back,
/// and overwriting a change you never saw is the worst failure an edit screen
/// has.
class EditSubscriptionScreen extends ConsumerWidget {
  const EditSubscriptionScreen({required this.subscriptionId, super.key});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Subscription?> subscription = ref.watch(
      subscriptionProvider(subscriptionId),
    );
    final SubscriptionWriteState state = ref.watch(
      subscriptionWriteControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit subscription'),
        leading: IconButton(
          onPressed: state.isSaving
              ? null
              : () => closeSubscriptionForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: switch (subscription) {
          AsyncLoading<Subscription?>() => const Center(
            child: AppLoadingIndicator(),
          ),
          AsyncError<Subscription?>(error: final Object error) => AppErrorState(
            error: error,
            onRetry: () => ref.invalidate(subscriptionProvider(subscriptionId)),
          ),
          // A null is a subscription that is not there *for this user* —
          // deleted, or someone else's. The two are the same answer under RLS
          // and have to stay the same answer, so the message says neither.
          AsyncData<Subscription?>(value: null) => const AppStateMessage(
            icon: Icons.search_off_rounded,
            title: 'Subscription not found',
            message:
                'This subscription is no longer here. It may have been deleted '
                'from another device.',
          ),
          AsyncData<Subscription?>(value: final Subscription found) =>
            SubscriptionForm(
              // Keyed by the subscription, so arriving at a different one
              // rebuilds the fields instead of showing the previous one's values
              // in them.
              key: ValueKey<String>(found.id),
              submitLabel: 'Save changes',
              initial: SubscriptionFormValues.of(found),
              isSaving: state.isSaving,
              errorMessage: state.errorMessage,
              onSubmit: (SubscriptionFormValues values) =>
                  _save(context, ref, found, values),
            ),
        },
      ),
    );
  }

  /// Writes both halves, then leaves.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Subscription original,
    SubscriptionFormValues values,
  ) async {
    // The rule may have moved. `rescheduled` decides what that does to the
    // bookmark — never backwards, so an edit cannot regenerate a month that has
    // already been billed. See RecurringBill.rescheduled.
    final RecurringBill template = original.template
        .rescheduled(values.recurrence)
        .copyWith(
          name: values.effectiveName,
          amount: values.money,
          categoryId: values.categoryId,
          // The provider is the payee, as it is on create. Kept in step here so
          // renaming the service renames it on the bills it generates from now
          // on.
          payee: values.provider.trim(),
        )
        // `copyWith` reads null as "leave it", so unfiling a subscription takes
        // saying so separately. Without this, clearing the category on the form
        // would silently keep the old one.
        .clearing(category: values.categoryId == null);

    final Subscription? saved = await ref
        .read(subscriptionWriteControllerProvider.notifier)
        .update(
          template: template,
          details: original.details.copyWith(
            provider: values.provider.trim(),
            planName: values.plan,
            trialEndsOn: values.trialEndsOn,
            autoRenews: values.autoRenews,
            cancellationUrl: values.cancellationUrl,
            // `copyWith` treats null as "leave it", so clearing a field takes
            // saying so. Without these three flags, emptying the plan, the trial
            // or the cancellation link would silently do nothing.
            clearPlanName: values.plan == null,
            clearTrialEndsOn: values.trialEndsOn == null,
            clearCancellationUrl: values.cancellationUrl == null,
          ),
        );

    if (saved == null || !context.mounted) {
      return;
    }

    // The row this screen read is now out of date. Invalidated rather than
    // patched: the list recomputes trial countdowns and next dates, and only the
    // database knows what they are for a row it has just written.
    ref.invalidate(subscriptionProvider(subscriptionId));

    showAppToast(
      context,
      message: '${saved.details.provider} updated',
      tone: AppToastTone.success,
    );

    closeSubscriptionForm(context);
  }
}
