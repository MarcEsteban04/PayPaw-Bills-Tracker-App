import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_write_controller.dart';
import 'package:paypaw/features/bills/presentation/screens/bills_screen.dart';
import 'package:paypaw/features/bills/presentation/widgets/bill_form.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../../bills/helpers/fake_bill_repository.dart';
import '../../payments/helpers/fake_payment_repository.dart';
import '../helpers/fake_recurring_bill_repository.dart';

/// What the client is responsible for in Sprint 31.
///
/// Generation itself lives in SQL — see
/// `supabase/migrations/0016_generate_recurring_bills.sql`. The app's share is
/// narrower: ask for it at the right moments, do not ask more often than that, do
/// not let a failure take the screen down, and write a *template* rather than a
/// bill when the form carries a recurrence.
void main() {
  const List<Category> categories = <Category>[
    Category(
      id: 'cat-internet',
      name: 'Internet',
      iconName: 'wifi',
      colorHex: '#6366F1',
      sortOrder: 10,
    ),
  ];

  late FakeBillRepository bills;
  late FakeRecurringBillRepository recurring;

  BillWithStatus item() => BillWithStatus(
    bill: Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Converge',
      amount: const Money.php(150000),
      dueOn: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: BillStatus.upcoming,
    paid: const Money.php(0),
    outstanding: const Money.php(150000),
    today: DateTime(2026, 8, 25),
  );

  /// The template the generated bill below came from.
  RecurringBill template() => RecurringBill(
    id: 'rec-1',
    userId: 'user-1',
    kind: RecurringBillKind.bill,
    name: 'Converge',
    amount: const Money.php(150000),
    recurrence: Recurrence(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
      startsOn: DateTime(2026, 8, 2),
    ),
    nextDueOn: DateTime(2026, 10, 15),
    isActive: true,
    createdAt: DateTime(2026, 8, 2),
    updatedAt: DateTime(2026, 8, 2),
  );

  /// A bill the generator made, which is to say one carrying a template id.
  BillWithStatus generated() => BillWithStatus(
    bill: Bill(
      id: 'bill-2',
      userId: 'user-1',
      recurringBillId: 'rec-1',
      name: 'Converge',
      amount: const Money.php(150000),
      dueOn: DateTime(2026, 9, 15),
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
    ),
    status: BillStatus.upcoming,
    paid: const Money.php(0),
    outstanding: const Money.php(150000),
    today: DateTime(2026, 8, 25),
  );

  setUp(() {
    bills = FakeBillRepository(bills: <BillWithStatus>[item()]);
    recurring = FakeRecurringBillRepository();
  });

  Future<void> pumpBillsScreen(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 1400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(bills),
          recurringBillRepositoryProvider.overrideWithValue(recurring),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
          categoriesProvider.overrideWith(
            (Ref ref) => Future<List<Category>>.value(categories),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.bills.path,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.bills.path,
                name: AppRoutes.bills.routeName,
                builder: (_, _) => const BillsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('opening the bills list', () {
    testWidgets('asks the server to generate anything due', (
      WidgetTester tester,
    ) async {
      // The scheduled job is the mechanism; this is the safety net. A template
      // created a moment ago should produce its bills now, and an installation
      // whose pg_cron was never enabled should still work.
      await pumpBillsScreen(tester);

      expect(recurring.generateCalls, 1);
    });

    testWidgets('and does not ask again on a refresh', (
      WidgetTester tester,
    ) async {
      // Cached for the session. Generation is idempotent, so a second call would
      // be harmless — but it is a round trip on every pull-to-refresh for work
      // the database has already done.
      await pumpBillsScreen(tester);
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(recurring.generateCalls, 1);
      // The refresh itself did happen.
      expect(bills.fetchCalls, greaterThan(1));
    });

    testWidgets('a generation failure does not take the list with it', (
      WidgetTester tester,
    ) async {
      // "No new bills yet" is not "the bills list is broken". The rows already
      // fetched are perfectly good, and an AsyncError reaching the screen would
      // replace them with an error state.
      recurring.generateFailure = const NetworkException();

      await pumpBillsScreen(tester);

      expect(find.text('Converge'), findsOneWidget);
      expect(find.textContaining('No internet'), findsNothing);
    });

    testWidgets('the bills are fetched after generation, not before', (
      WidgetTester tester,
    ) async {
      // Otherwise the list is correct and then silently grows a moment later.
      await pumpBillsScreen(tester);

      expect(recurring.generateCalls, 1);
      expect(bills.fetchCalls, 1);
    });
  });

  group('a generated bill', () {
    testWidgets('is marked as repeating in the list', (
      WidgetTester tester,
    ) async {
      // `recurring_bill_id` was set by the generator from the day it existed and
      // rendered nowhere, so a bill that reappears every month looked exactly
      // like one somebody had entered twice.
      bills = FakeBillRepository(bills: <BillWithStatus>[generated(), item()]);

      await pumpBillsScreen(tester);

      expect(find.byTooltip('Repeats'), findsOneWidget);
    });

    testWidgets('and the drawer says what the schedule is', (
      WidgetTester tester,
    ) async {
      // Not just "this repeats" — the rule itself, which is the thing a reader
      // wants to check when a bill turns up they were not expecting.
      bills = FakeBillRepository(bills: <BillWithStatus>[generated()]);
      recurring = FakeRecurringBillRepository(
        templates: <RecurringBill>[template()],
      );

      await pumpBillsScreen(tester);
      await tester.tap(find.text('Converge'));
      await tester.pumpAndSettle();

      expect(find.text('Repeats'), findsOneWidget);
      expect(find.text('Every month on the 15th'), findsOneWidget);
    });

    testWidgets('a plain bill is not marked', (WidgetTester tester) async {
      await pumpBillsScreen(tester);

      expect(find.byTooltip('Repeats'), findsNothing);
    });
  });

  group('the controller', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          billRepositoryProvider.overrideWithValue(bills),
          recurringBillRepositoryProvider.overrideWithValue(recurring),
        ],
      );
      addTearDown(container.dispose);
    });

    BillFormValues values({Recurrence? recurrence}) => BillFormValues(
      name: '  Converge  ',
      amount: '1,500.00',
      dueOn: DateTime(2026, 9, 5),
      recurrence: recurrence,
    );

    Recurrence monthly() => Recurrence(
      frequency: RecurrenceFrequency.monthly,
      dayOfMonth: 15,
      startsOn: DateTime(2026, 9, 5),
    );

    test('a failed generation does not fail the save', () async {
      // The template is stored either way, and tonight's job produces the same
      // occurrences. Losing the save because a follow-up call timed out would
      // throw away work the user has already done.
      recurring.generateFailure = const NetworkException();

      final bool saved = await container
          .read(billWriteControllerProvider.notifier)
          .create(values(recurrence: monthly()));

      expect(saved, isTrue);
      expect(recurring.created, isNotNull);
      expect(container.read(billWriteControllerProvider).errorMessage, isNull);
    });

    test('a failed template write does fail the save', () async {
      recurring.failure = const NetworkException();

      final bool saved = await container
          .read(billWriteControllerProvider.notifier)
          .create(values(recurrence: monthly()));

      expect(saved, isFalse);
      expect(
        container.read(billWriteControllerProvider).errorMessage,
        contains('No internet'),
      );
    });

    test('the form due date is the schedule start, not an occurrence', () async {
      // "Due on the 5th, monthly on the 15th" is two answers to one question,
      // and the rule is the one that has to win. The 5th is where the schedule
      // begins; the first bill is the 15th.
      await container
          .read(billWriteControllerProvider.notifier)
          .create(values(recurrence: monthly()));

      expect(recurring.created!.recurrence.startsOn, DateTime(2026, 9, 5));
      expect(recurring.created!.nextDueOn, DateTime(2026, 9, 15));
    });

    test('reports the saved name so the screen can leave', () async {
      // Both write paths set it. The recurring one has no Bill to report, which
      // is why the state carries a name rather than the entity.
      await container
          .read(billWriteControllerProvider.notifier)
          .create(values(recurrence: monthly()));

      expect(container.read(billWriteControllerProvider).savedName, 'Converge');
    });

    test(
      'a schedule that never comes due is refused before the round trip',
      () {
        final Recurrence impossible = Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 15,
          startsOn: DateTime(2026, 9, 2),
          endsOn: DateTime(2026, 9, 10),
        );

        expect(
          container
              .read(billWriteControllerProvider.notifier)
              .create(values(recurrence: impossible)),
          completion(isFalse),
        );
      },
    );
  });
}
