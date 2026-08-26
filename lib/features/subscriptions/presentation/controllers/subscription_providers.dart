import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../../data/repositories/composite_subscription_repository.dart';
import '../../data/repositories/supabase_subscription_details_store.dart';
import '../../domain/entities/subscription.dart';
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
