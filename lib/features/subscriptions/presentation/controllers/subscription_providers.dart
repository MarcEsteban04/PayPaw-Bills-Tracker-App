import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../../data/repositories/composite_subscription_repository.dart';
import '../../data/repositories/supabase_subscription_details_store.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_group.dart';
import '../../domain/entities/subscription_sort.dart';
import '../../domain/entities/subscription_spend.dart';
import '../../domain/repositories/subscription_details_store.dart';
import '../../domain/repositories/subscription_repository.dart';

final Provider<SubscriptionDetailsStore> subscriptionDetailsStoreProvider =
    Provider<SubscriptionDetailsStore>(
      (Ref ref) =>
          SupabaseSubscriptionDetailsStore(ref.watch(supabaseClientProvider)),
    );

final Provider<SubscriptionRepository> subscriptionRepositoryProvider =
    Provider<SubscriptionRepository>(
      (Ref ref) => CompositeSubscriptionRepository(
        ref.watch(recurringBillRepositoryProvider),
        ref.watch(subscriptionDetailsStoreProvider),
      ),
    );

/// Every subscription the signed-in user has, soonest billing first.
///
/// Includes paused and finished ones. A subscription somebody stopped is still
/// worth seeing on a list of subscriptions — it is the record of a decision, and
/// hiding it would leave them wondering whether it ever existed.
/// `Subscription.isActive` is what separates the two for anything that needs to.
///
/// Empty rather than an error when signed out: there is nothing to fetch and
/// every screen above this already copes with having none.
final FutureProvider<List<Subscription>> subscriptionsProvider =
    FutureProvider<List<Subscription>>((Ref ref) async {
      if (ref.watch(currentUserProvider).value == null) {
        return const <Subscription>[];
      }

      return ref.watch(subscriptionRepositoryProvider).fetchSubscriptions();
    });

/// One subscription, by id.
///
/// A family rather than a lookup in the list, because a detail screen reached by
/// a deep link has no list to look in — and reading the row directly is what
/// makes it open on what the database currently holds rather than on what a list
/// was showing minutes ago.
final subscriptionProvider = FutureProvider.family<Subscription?, String>(
  (Ref ref, String id) =>
      ref.watch(subscriptionRepositoryProvider).fetchSubscription(id),
);

/// Today, as the database sees it.
///
/// Taken from the bills the server has already dated rather than from the device
/// clock, so a trial countdown cannot disagree with the due dates on the screen
/// behind it. Falls back to the clock when no bills have loaded, which is the
/// only time there is nothing better to ask.
final Provider<DateTime> subscriptionTodayProvider = Provider<DateTime>(
  (Ref ref) =>
      ref.watch(billsProvider).value?.firstOrNull?.today ?? DateTime.now(),
);

/// What the subscriptions cost, and which ones cost the most.
///
/// Derived rather than fetched. The figures are a pure function of the list and
/// the date, so a provider that recomputed them from its own query would be a
/// second source for the same fact — and the two would disagree for as long as
/// one of them was stale.
final Provider<SubscriptionSpend> subscriptionSpendProvider =
    Provider<SubscriptionSpend>((Ref ref) {
      final List<Subscription> subscriptions =
          ref.watch(subscriptionsProvider).value ?? const <Subscription>[];

      return SubscriptionSpend.of(
        subscriptions,
        today: ref.watch(subscriptionTodayProvider),
      );
    });

/// How the list is ordered.
///
/// A `Notifier` rather than a `StateProvider` so the reason for each order can
/// live with the method that sets it — the same shape `BillFilterController`
/// uses, for the same reason.
class SubscriptionSortController extends Notifier<SubscriptionSort> {
  @override
  SubscriptionSort build() => SubscriptionSort.nextCharge;

  void set(SubscriptionSort sort) => state = sort;
}

final NotifierProvider<SubscriptionSortController, SubscriptionSort>
subscriptionSortProvider =
    NotifierProvider<SubscriptionSortController, SubscriptionSort>(
      SubscriptionSortController.new,
    );

/// The list in the order the user asked for.
///
/// Sorted here rather than in the screen: an order is a fact about the data, and
/// a list arranged inside a `build` is one no test can reach without pumping a
/// widget.
final Provider<List<Subscription>>
sortedSubscriptionsProvider = Provider<List<Subscription>>((Ref ref) {
  final List<Subscription> subscriptions =
      ref.watch(subscriptionsProvider).value ?? const <Subscription>[];

  return switch (ref.watch(subscriptionSortProvider)) {
    // Already soonest-first from the repository, so this is the query's own
    // order rather than a second opinion about it.
    SubscriptionSort.nextCharge => subscriptions,
    // Dearest first, and stopped ones after everything live — a subscription
    // that costs nothing because it was cancelled does not belong among the
    // cheap ones, it belongs at the bottom.
    SubscriptionSort.cost => <Subscription>[
      ...ref.watch(subscriptionSpendProvider).ranked,
      ...subscriptions.where((Subscription each) => !each.isActive),
    ],
  };
});

/// The list, in the chosen order, split into sections.
///
/// Grouped here rather than in the screen for the same reason the sort is: what
/// kind of thing a row is, and therefore where it sits, is a fact about the data
/// — and a list arranged inside a `build` is one no test can reach without
/// pumping a widget.
final Provider<List<SubscriptionSection>> subscriptionSectionsProvider =
    Provider<List<SubscriptionSection>>(
      (Ref ref) => groupSubscriptions(
        ref.watch(sortedSubscriptionsProvider),
        today: ref.watch(subscriptionTodayProvider),
      ),
    );
