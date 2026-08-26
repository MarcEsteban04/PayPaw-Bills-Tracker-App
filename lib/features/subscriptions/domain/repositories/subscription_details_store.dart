import '../entities/subscription_details.dart';

/// The extension table on its own.
///
/// Split out from [SubscriptionRepository] so the joining-up — and in
/// particular the compensating delete when half a create fails — can be tested
/// without a live PostgREST client. That compensation is the one piece of logic
/// in this feature that prevents corrupt data, and logic that cannot be tested
/// is logic nobody can be sure of.
///
/// Ownership is never a parameter: `user_id` comes from the session inside the
/// implementation, so no call site can pass somebody else's.
abstract interface class SubscriptionDetailsStore {
  /// Every extension row the signed-in user has, by recurring bill id.
  Future<Map<String, SubscriptionDetails>> fetchAll();

  /// One row, or null when there is none visible to this user.
  Future<SubscriptionDetails?> fetch(String recurringBillId);

  /// Writes a row and returns it as stored.
  Future<SubscriptionDetails> save(SubscriptionDetails details);
}
