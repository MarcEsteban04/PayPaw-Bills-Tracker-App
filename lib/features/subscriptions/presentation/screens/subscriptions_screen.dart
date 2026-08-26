import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_sort.dart';
import '../../domain/entities/subscription_spend.dart';
import '../controllers/subscription_providers.dart';
import '../controllers/subscription_write_controller.dart';
import '../widgets/subscription_detail_sheet.dart';
import '../widgets/subscription_spend_card.dart';
import '../widgets/subscription_tile.dart';

/// What the user is paying for, what it costs, and what to cancel.
///
/// ## Why this is not a fifth tab
///
/// Four destinations is what the reference design's navigation bar holds and
/// what fits at 320dp. A subscription list is something people check monthly and
/// act on twice a year; it does not earn a permanent slot next to the bills they
/// look at daily. It is reached from the dashboard and from the Bills header
/// instead — the latter because this screen's charges are what that list is
/// full of.
///
/// ## Stopped subscriptions stay on the list
///
/// A subscription somebody cancelled is the record of a decision, and hiding it
/// would leave them wondering whether it ever existed — or, worse, adding it
/// again. It is dimmed and labelled rather than removed, and left out of every
/// figure above. Deleting is the way to make one go away, and that is deliberate
/// friction.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Subscription>> subscriptions = ref.watch(
      subscriptionsProvider,
    );
    final SubscriptionSort sort = ref.watch(subscriptionSortProvider);

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
          // Only once there is more than one to order. A sort control over a
          // single row is a control that cannot change anything.
          if ((subscriptions.value?.length ?? 0) > 1)
            IconButton(
              onPressed: () => _pickSort(context, ref, sort),
              tooltip: 'Sort: ${sort.label}',
              isSelected: !sort.isDefault,
              icon: const Icon(Icons.swap_vert_rounded),
            ),
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

  Future<void> _pickSort(
    BuildContext context,
    WidgetRef ref,
    SubscriptionSort current,
  ) async {
    final SubscriptionSort? chosen = await showAppBottomSheet<SubscriptionSort>(
      context: context,
      title: 'Sort by',
      child: _SortOptions(current: current),
    );

    if (chosen != null) {
      ref.read(subscriptionSortProvider.notifier).set(chosen);
    }
  }
}

class _SortOptions extends StatelessWidget {
  const _SortOptions({required this.current});

  final SubscriptionSort current;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final SubscriptionSort option in SubscriptionSort.values)
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => Navigator.of(context).pop(option),
            title: Text(option.label),
            subtitle: Text(switch (option) {
              SubscriptionSort.nextCharge => 'Soonest first',
              // Says which figure it sorts on, because the answer is not the
              // number printed on the row when a plan is not monthly.
              SubscriptionSort.cost => 'Dearest first, per month',
            }, style: TextStyle(color: colors.textSecondary)),
            trailing: option == current
                ? Icon(Icons.check_rounded, color: colors.primary)
                : null,
          ),
      ],
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
    final DateTime today = ref.watch(subscriptionTodayProvider);
    final SubscriptionSpend spend = ref.watch(subscriptionSpendProvider);
    final List<Subscription> ordered = ref.watch(sortedSubscriptionsProvider);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        AppSpacing.bottomNavClearance,
      ),
      // One extra for the card at the top. Inside the list rather than pinned
      // above it, so the figures scroll away and the rows get the whole screen —
      // on a phone holding a dozen subscriptions, a header that never moves
      // costs a third of the list forever.
      itemCount: ordered.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          // Absent when every subscription is stopped: a card reading "₱0.00 a
          // month · 0 subscriptions" is a card that says nothing the list below
          // does not already say more clearly.
          return spend.hasAnything
              ? SubscriptionSpendCard(spend: spend)
              : const SizedBox.shrink();
        }

        final Subscription subscription = ordered[index - 1];

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
