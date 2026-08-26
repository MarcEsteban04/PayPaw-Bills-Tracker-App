import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_providers.dart';
import '../controllers/subscription_write_controller.dart';
import '../widgets/subscription_detail_sheet.dart';
import '../widgets/subscription_tile.dart';

/// What the user is paying for, and what it costs.
///
/// ## Why this is not a fifth tab
///
/// Four destinations is what the reference design's navigation bar holds and
/// what fits at 320dp. A subscription list is something people check monthly and
/// act on twice a year; it does not earn a permanent slot next to the bills they
/// look at daily. It is reached from the dashboard instead.
///
/// ## Stopped subscriptions stay on the list
///
/// A subscription somebody cancelled is the record of a decision, and hiding it
/// would leave them wondering whether it ever existed — or, worse, adding it
/// again. It is dimmed and labelled rather than removed. Deleting is the way to
/// make one go away, and that is deliberate friction.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subscription>> subscriptions = ref.watch(
      subscriptionsProvider,
    );

    // Failures from every write on this screen, in one place. The sheets and
    // dialogs that started them are gone by the time a request fails.
    ref.listen<SubscriptionWriteState>(subscriptionWriteControllerProvider, (
      SubscriptionWriteState? previous,
      SubscriptionWriteState next,
    ) {
      if (next.errorMessage case final String message
          when message != previous?.errorMessage) {
        showAppToast(context, message: message, tone: AppToastTone.error);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                context.pushNamed(AppRoutes.addSubscription.routeName),
            tooltip: 'Add a subscription',
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: AppContentWidth(
          child: switch (subscriptions) {
            // Matched before the loading case. During a refresh the list is
            // already on screen and correct, and replacing it with a spinner
            // would blank it every time one is edited.
            AsyncValue<List<Subscription>>(
              value: final List<Subscription> found?,
            ) =>
              _List(subscriptions: found),
            AsyncError<List<Subscription>>(error: final Object error) =>
              AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(subscriptionsProvider),
              ),
            _ => const Center(child: AppLoadingIndicator()),
          },
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subscriptions.isEmpty) {
      return AppEmptyState(
        icon: Icons.subscriptions_outlined,
        title: 'No subscriptions yet',
        message:
            'Add the things that charge you every month — streaming, storage, '
            'the gym — and PayPaw will tell you before each one renews.',
        actionLabel: 'Add a subscription',
        onAction: () => context.pushNamed(AppRoutes.addSubscription.routeName),
      );
    }

    // Today from the database, like everywhere else: a trial countdown computed
    // against a wrong phone clock would disagree with the due dates beside it.
    final DateTime today =
        ref.watch(billsProvider).value?.firstOrNull?.today ?? DateTime.now();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        AppSpacing.bottomNavClearance,
      ),
      itemCount: subscriptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (BuildContext context, int index) {
        final Subscription subscription = subscriptions[index];

        return SubscriptionTile(
          subscription: subscription,
          today: today,
          onTap: () => showSubscriptionDetailSheet(
            context: context,
            ref: ref,
            subscription: subscription,
            today: today,
          ),
        );
      },
    );
  }
}
