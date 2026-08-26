import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/data/repositories/composite_subscription_repository.dart';
import 'package:paypaw/features/subscriptions/domain/entities/new_subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';

import '../../recurring/helpers/fake_recurring_bill_repository.dart';
import '../helpers/fake_subscription_details_store.dart';

/// Joining the two rows a subscription is.
///
/// The interesting part is not the reading. It is what happens when **half a
/// create lands**: PostgREST gives the client no transaction, so writing the
/// template and then the extension can leave a subscription with no provider —
/// a thing nobody can identify or cancel and nothing would ever clean up.
void main() {
  final Recurrence monthly = Recurrence(
    frequency: RecurrenceFrequency.monthly,
    startsOn: DateTime(2026, 9, 18),
    dayOfMonth: 18,
  );

  RecurringBill template({
    required String id,
    RecurringBillKind kind = RecurringBillKind.subscription,
    String name = 'Netflix',
  }) => RecurringBill(
    id: id,
    userId: 'user-1',
    kind: kind,
    name: name,
    amount: const Money.php(54900),
    recurrence: monthly,
    nextDueOn: DateTime(2026, 9, 18),
    isActive: true,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  SubscriptionDetails details(String id, {String provider = 'Netflix'}) =>
      SubscriptionDetails(recurringBillId: id, provider: provider);

  late FakeRecurringBillRepository recurring;
  late FakeSubscriptionDetailsStore store;

  CompositeSubscriptionRepository repositoryWith({
    List<RecurringBill> templates = const <RecurringBill>[],
    Map<String, SubscriptionDetails> rows =
        const <String, SubscriptionDetails>{},
  }) {
    recurring = FakeRecurringBillRepository(templates: templates);
    store = FakeSubscriptionDetailsStore(rows: rows);

    return CompositeSubscriptionRepository(recurring, store);
  }

  final NewSubscription draft = NewSubscription(
    name: 'Netflix',
    amount: const Money.php(54900),
    recurrence: monthly,
    provider: 'Netflix',
  );

  group('reading', () {
    test('joins a template to its extension', () async {
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[template(id: 'sub-1')],
        rows: <String, SubscriptionDetails>{'sub-1': details('sub-1')},
      );

      final List<Subscription> found = await repository.fetchSubscriptions();

      expect(found, hasLength(1));
      expect(found.single.name, 'Netflix');
      expect(found.single.details.provider, 'Netflix');
    });

    test('leaves out an ordinary recurring bill', () async {
      // A template that is not a subscription has no business here even if a
      // stray extension row exists for it.
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[
          template(id: 'rent', kind: RecurringBillKind.bill, name: 'Rent'),
        ],
        rows: <String, SubscriptionDetails>{'rent': details('rent')},
      );

      expect(await repository.fetchSubscriptions(), isEmpty);
    });

    test('and leaves out a subscription with no extension row', () async {
      // The half-written record the create below compensates for. Showing it
      // would mean a subscription with no provider — nothing anybody can
      // identify or cancel.
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[template(id: 'sub-1')],
      );

      expect(await repository.fetchSubscriptions(), isEmpty);
    });

    test('one by id is null when it is not a subscription', () async {
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[
          template(id: 'rent', kind: RecurringBillKind.bill),
        ],
        rows: <String, SubscriptionDetails>{'rent': details('rent')},
      );

      expect(await repository.fetchSubscription('rent'), isNull);
    });

    test('and null when the extension is missing', () async {
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[template(id: 'sub-1')],
      );

      expect(await repository.fetchSubscription('sub-1'), isNull);
    });
  });

  group('creating', () {
    test('writes the template first, then the extension', () async {
      // That order, because the extension's primary key is the template's id.
      final CompositeSubscriptionRepository repository = repositoryWith();

      final Subscription created = await repository.createSubscription(draft);

      expect(recurring.created?.kind, RecurringBillKind.subscription);
      expect(store.saved.single.recurringBillId, created.template.id);
      expect(created.details.provider, 'Netflix');
    });

    test('the provider becomes the payee', () async {
      // It is who the money goes to, which is what that column means — and it
      // keeps a generated bill saying "Netflix" on the bills list without the
      // list knowing subscriptions exist.
      final CompositeSubscriptionRepository repository = repositoryWith();

      await repository.createSubscription(draft);

      expect(recurring.created?.payee, 'Netflix');
    });

    test('refuses a draft the database would refuse', () async {
      // Before the round trip, so a form can say what is wrong rather than
      // surfacing a Postgres error.
      final CompositeSubscriptionRepository repository = repositoryWith();

      await expectLater(
        repository.createSubscription(
          NewSubscription(
            name: 'Netflix',
            amount: const Money.php(54900),
            recurrence: monthly,
            provider: '   ',
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(recurring.created, isNull);
    });

    test('undoes the template when the extension fails', () async {
      // The compensation. Without it the account keeps a subscription-kind
      // template with no provider — invisible to the subscriptions list, still
      // generating bills, and nothing would ever clean it up.
      final CompositeSubscriptionRepository repository = repositoryWith();
      store.failSave = const NetworkException();

      await expectLater(
        repository.createSubscription(draft),
        throwsA(isA<NetworkException>()),
      );

      expect(recurring.deleted, isNotNull);
      expect(await repository.fetchSubscriptions(), isEmpty);
    });

    test('and reports the original failure, not the cleanup', () async {
      // The caller is about to be told the create failed, which is true and is
      // the useful half. A different error about the cleanup would replace a
      // message they can act on with one they cannot.
      final CompositeSubscriptionRepository repository = repositoryWith();
      store.failSave = const NetworkException();
      recurring.deleteFailure = const ServerException();

      await expectLater(
        repository.createSubscription(draft),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('updating and deleting', () {
    test('the service half goes to the extension store', () async {
      final CompositeSubscriptionRepository repository = repositoryWith();

      await repository.updateDetails(
        details('sub-1').copyWith(planName: 'Premium'),
      );

      expect(store.saved.single.planName, 'Premium');
    });

    test('and a bad one is refused before the round trip', () async {
      final CompositeSubscriptionRepository repository = repositoryWith();

      await expectLater(
        repository.updateDetails(details('sub-1', provider: '')),
        throwsA(isA<ValidationException>()),
      );

      expect(store.saved, isEmpty);
    });

    test('deleting is one delete, and the cascade does the rest', () async {
      // `subscriptions.recurring_bill_id` is `on delete cascade`. A client that
      // deleted both by hand would be a client that could stop halfway.
      final CompositeSubscriptionRepository repository = repositoryWith(
        templates: <RecurringBill>[template(id: 'sub-1')],
        rows: <String, SubscriptionDetails>{'sub-1': details('sub-1')},
      );

      await repository.deleteSubscription('sub-1');

      expect(recurring.deleted, 'sub-1');
    });
  });
}
