import '../../../../core/error/app_exception.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import '../../../recurring/domain/repositories/recurring_bill_repository.dart';
import '../../domain/entities/new_subscription.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_details.dart';
import '../../domain/repositories/subscription_details_store.dart';
import '../../domain/repositories/subscription_repository.dart';

/// [SubscriptionRepository] built from the two halves a subscription is.
///
/// ## It borrows the recurring repository rather than reimplementing it
///
/// The schedule half of a subscription is a recurring bill in every respect, so
/// creating and deleting one goes through [RecurringBillRepository]. A second
/// implementation of "insert a template" would be a second place for the
/// `next_due_on` derivation to be got wrong.
///
/// ## No Supabase in this file
///
/// Both collaborators are interfaces, which is what lets the compensating
/// delete below be tested — and that compensation is the only thing standing
/// between a failed create and a subscription nobody can name.
class CompositeSubscriptionRepository implements SubscriptionRepository {
  const CompositeSubscriptionRepository(this._recurring, this._details);

  final RecurringBillRepository _recurring;
  final SubscriptionDetailsStore _details;

  @override
  Future<List<Subscription>> fetchSubscriptions({
    bool includeInactive = true,
  }) async {
    // Two reads, not a PostgREST embed.
    //
    // An embed would tie this to a foreign-key relationship name that lives in
    // the database and appears in no Dart file — rename the constraint and this
    // breaks at runtime with a message about a relationship. Two reads cost one
    // extra round trip on a table holding a handful of rows per user.
    final List<RecurringBill> templates = await _recurring.fetchRecurringBills(
      includeInactive: includeInactive,
    );
    final Map<String, SubscriptionDetails> byTemplate = await _details
        .fetchAll();

    return <Subscription>[
      for (final RecurringBill template in templates)
        // Both conditions. A template that is not a subscription has no business
        // here even if a stray extension row exists, and a subscription-kind
        // template with no extension is the half-written record
        // [createSubscription] compensates for.
        if (template.kind == RecurringBillKind.subscription)
          if (byTemplate[template.id] case final SubscriptionDetails details)
            Subscription(template: template, details: details),
    ];
  }

  @override
  Future<Subscription?> fetchSubscription(String id) async {
    final RecurringBill? template = await _recurring.fetchRecurringBill(id);

    if (template == null || template.kind != RecurringBillKind.subscription) {
      return null;
    }

    final SubscriptionDetails? details = await _details.fetch(id);

    return details == null
        ? null
        : Subscription(template: template, details: details);
  }

  @override
  Future<Subscription> createSubscription(NewSubscription draft) async {
    if (draft.validate() case final String problem) {
      throw ValidationException(
        message: problem,
        debugMessage: 'NewSubscription rejected before the round trip',
      );
    }

    // The template first, because the extension's primary key is its id.
    final RecurringBill template = await _recurring.createRecurringBill(
      draft.template,
    );

    try {
      final SubscriptionDetails saved = await _details.save(
        draft.detailsFor(template.id),
      );

      return Subscription(template: template, details: saved);
    } on Object {
      // Compensate. PostgREST gives the client no transaction, so the only way
      // not to leave a subscription with no provider is to undo the half that
      // did land. The template is seconds old and has generated nothing.
      //
      // The cleanup's own failure is swallowed on purpose: the caller is about
      // to be told the create failed, which is true and is the useful half. A
      // second, different error about the cleanup would replace a message they
      // can act on with one they cannot.
      try {
        await _recurring.deleteRecurringBill(template.id);
      } on Object {
        // See the contract: what is left behaves as an ordinary recurring bill.
      }

      rethrow;
    }
  }

  @override
  Future<SubscriptionDetails> updateDetails(SubscriptionDetails details) async {
    if (details.validate() case final String problem) {
      throw ValidationException(
        message: problem,
        debugMessage: 'SubscriptionDetails rejected before the round trip',
      );
    }

    return _details.save(details);
  }

  @override
  Future<void> deleteSubscription(String id) =>
      // One delete. The extension goes with it by cascade — see the contract.
      _recurring.deleteRecurringBill(id);
}
