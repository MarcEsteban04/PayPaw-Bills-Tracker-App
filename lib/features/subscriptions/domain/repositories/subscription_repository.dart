import '../entities/new_subscription.dart';
import '../entities/subscription.dart';
import '../entities/subscription_details.dart';

/// Reads and writes subscriptions.
///
/// ## A subscription is two rows
///
/// The schedule lives in `recurring_bills` and the service-specific half in
/// `subscriptions`. This repository is what makes them look like one thing, and
/// it is the only place that knows they are two.
///
/// ## Ownership is never a parameter
///
/// No method takes a `userId`. RLS restricts every statement to the signed-in
/// user, and the writes take it from the session.
abstract interface class SubscriptionRepository {
  /// Every subscription the signed-in user has, soonest billing first.
  ///
  /// **A template with no extension row is left out.** `kind = 'subscription'`
  /// with nothing in `subscriptions` is a half-written record — see
  /// [createSubscription] — and showing it would mean a subscription with no
  /// provider, which is a thing nobody can identify or cancel.
  Future<List<Subscription>> fetchSubscriptions({bool includeInactive = true});

  /// One subscription, or null when there is no such thing visible to this user.
  ///
  /// Null rather than an exception for a missing row: through RLS "deleted" and
  /// "belongs to someone else" are the same answer and have to stay that way.
  Future<Subscription?> fetchSubscription(String id);

  /// Creates both rows and returns the result.
  ///
  /// **Not atomic, and compensated.** PostgREST has no client transaction, so
  /// this writes the template and then the extension. If the second fails the
  /// first is deleted again before the error is rethrown — the template is
  /// seconds old and has generated nothing, so removing it costs nothing and
  /// leaves no half-subscription behind.
  ///
  /// If the compensating delete *also* fails, a `kind = 'subscription'` template
  /// is left with no extension. [fetchSubscriptions] ignores it; it behaves as
  /// an ordinary recurring bill, which is a smaller wrong than a subscription
  /// nobody can name.
  Future<Subscription> createSubscription(NewSubscription draft);

  /// Saves changes to the service half.
  ///
  /// The schedule half is edited through `RecurringBillRepository`, because it
  /// is the same edit for a subscription as for any other repeating bill and two
  /// paths to it would be two chances to disagree.
  Future<SubscriptionDetails> updateDetails(SubscriptionDetails details);

  /// Destroys a subscription: the template and, by cascade, its extension.
  ///
  /// One delete, not two. `subscriptions.recurring_bill_id` is
  /// `on delete cascade`, so the database removes the extension — and a client
  /// that deleted both by hand would be a client that could stop halfway.
  ///
  /// The bills it already generated survive as ordinary bills. Cancelling a
  /// subscription is "stop charging me", not "those months never happened".
  Future<void> deleteSubscription(String id);
}
