import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../domain/entities/new_subscription.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_write_controller.dart';
import '../widgets/subscription_form.dart';

/// Records a subscription.
///
/// A full screen rather than a sheet, for the reason `AddBillScreen` gives: the
/// form opens a date picker, a category sheet and a recurrence editor, and a
/// sheet that spawns sheets is a stack the user cannot see the shape of. Above
/// the shell, so the navigation bar does not sit under a form.
///
/// Thin on purpose. Everything the form does lives in [SubscriptionForm], which
/// the edit screen uses too; this file supplies the title, the button's word, and
/// what happens on success.
class AddSubscriptionScreen extends ConsumerWidget {
  const AddSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SubscriptionWriteState state = ref.watch(
      subscriptionWriteControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add subscription'),
        leading: IconButton(
          onPressed: state.isSaving
              ? null
              : () => closeSubscriptionForm(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: SubscriptionForm(
          submitLabel: 'Save subscription',
          isSaving: state.isSaving,
          errorMessage: state.errorMessage,
          onSubmit: (SubscriptionFormValues values) =>
              _save(context, ref, values),
        ),
      ),
    );
  }

  /// Writes it, then leaves.
  ///
  /// Awaited rather than watched through `ref.listen`, because the answer this
  /// screen needs — did this particular save land — is exactly what the call
  /// returns. A null is a failure the controller has already put on screen as an
  /// inline message, so there is nothing left to do but stay put.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    SubscriptionFormValues values,
  ) async {
    final Subscription? saved = await ref
        .read(subscriptionWriteControllerProvider.notifier)
        .create(
          NewSubscription(
            name: values.effectiveName,
            amount: values.money,
            recurrence: values.recurrence,
            provider: values.provider.trim(),
            planName: values.plan,
            categoryId: values.categoryId,
            trialEndsOn: values.trialEndsOn,
            autoRenews: values.autoRenews,
            cancellationUrl: values.cancellationUrl,
          ),
        );

    if (saved == null || !context.mounted) {
      return;
    }

    // Raised before the screen closes, and it survives that: the toast lives in
    // the root overlay rather than in this route's messenger, so a form that
    // dismisses itself does not take its own confirmation with it.
    showAppToast(
      context,
      message: '${saved.details.provider} saved',
      tone: AppToastTone.success,
    );

    closeSubscriptionForm(context);
  }
}

/// Leaves a subscription form.
///
/// `pop` when there is a stack, because the form is pushed over whatever the
/// user was looking at and they should return to it. The named fallback covers
/// being opened directly, which a deep link or a test can do.
void closeSubscriptionForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.goNamed(AppRoutes.subscriptions.routeName);
  }
}
