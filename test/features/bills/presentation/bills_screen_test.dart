import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/screens/bills_screen.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';

import '../helpers/fake_bill_repository.dart';

/// The bill list.
///
/// Deliberately the plain version — Sprint 28 adds search, filters and sorting.
/// It exists now because the edit form needs something to tap, and a feature that
/// cannot be reached cannot be tested.
void main() {
  const List<Category> categories = <Category>[
    Category(
      id: 'cat-electricity',
      name: 'Electricity',
      iconName: 'bolt',
      colorHex: '#F59E0B',
      sortOrder: 10,
    ),
  ];

  BillWithStatus item({
    String id = 'bill-1',
    String name = 'Meralco electricity',
    BillStatus status = BillStatus.dueSoon,
    int outstanding = 245050,
    int paid = 0,
    DateTime? dueOn,
    DateTime? archivedAt,
    String? categoryId = 'cat-electricity',
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      amount: const Money.php(245050),
      dueOn: dueOn ?? DateTime(2026, 9, 5),
      categoryId: categoryId,
      archivedAt: archivedAt,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(outstanding),
    today: DateTime(2026, 9, 3),
  );

  late FakeBillRepository repository;

  Future<void> pumpList(
    WidgetTester tester, {
    List<BillWithStatus> bills = const <BillWithStatus>[],
  }) async {
    repository = FakeBillRepository(bills: bills);

    tester.view
      ..physicalSize = const Size(392 * 3, 900 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(repository),
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
              GoRoute(
                path: AppRoutes.addBill.path,
                name: AppRoutes.addBill.routeName,
                builder: (_, _) => const Scaffold(body: Text('add stub')),
              ),
              GoRoute(
                path: AppRoutes.editBill.path,
                name: AppRoutes.editBill.routeName,
                builder: (_, GoRouterState state) =>
                    Scaffold(body: Text('edit ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('with no bills', () {
    testWidgets('it says so and offers the way out', (
      WidgetTester tester,
    ) async {
      // An empty list with no action is a dead end on the screen a new user
      // reaches first.
      await pumpList(tester);

      expect(find.text('No bills yet'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add bill'), findsOneWidget);
    });

    testWidgets('and that button opens the form', (WidgetTester tester) async {
      await pumpList(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add bill'));
      await tester.pumpAndSettle();

      expect(find.text('add stub'), findsOneWidget);
    });
  });

  group('with bills', () {
    testWidgets('each row shows what decides whether to act', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, bills: <BillWithStatus>[item()]);

      expect(find.text('Meralco electricity'), findsOneWidget);
      expect(find.text('Due in 2 days'), findsOneWidget);
      expect(find.text('Due soon'), findsOneWidget);
    });

    testWidgets('the amount shown is what is still owed', (
      WidgetTester tester,
    ) async {
      // Not the bill's total. A bill with ₱2,000 paid of ₱2,450 is a ₱450
      // problem, and showing the total would overstate every partially paid row.
      await pumpList(
        tester,
        bills: <BillWithStatus>[
          item(
            paid: 200000,
            outstanding: 45050,
            status: BillStatus.partiallyPaid,
          ),
        ],
      );

      expect(find.text('₱450.50'), findsOneWidget);
      expect(find.text('₱2,450.50'), findsNothing);
    });

    testWidgets('overdue is said in words, not only in colour', (
      WidgetTester tester,
    ) async {
      // Colour alone is not enough for someone who cannot see the difference.
      await pumpList(
        tester,
        bills: <BillWithStatus>[
          item(dueOn: DateTime(2026, 8, 30), status: BillStatus.overdue),
        ],
      );

      expect(find.text('4 days overdue'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('a settled bill does not nag about a date', (
      WidgetTester tester,
    ) async {
      await pumpList(
        tester,
        bills: <BillWithStatus>[
          item(paid: 245050, outstanding: 0, status: BillStatus.paid),
        ],
      );

      expect(find.text('Settled'), findsOneWidget);
    });

    testWidgets('tapping a row opens that bill', (WidgetTester tester) async {
      await pumpList(
        tester,
        bills: <BillWithStatus>[
          item(),
          item(id: 'bill-2', name: 'Globe fibre'),
        ],
      );

      await tester.tap(find.text('Globe fibre'));
      await tester.pumpAndSettle();

      expect(find.text('edit bill-2'), findsOneWidget);
    });

    testWidgets('a bill with no category still renders', (
      WidgetTester tester,
    ) async {
      // The column is nullable, and a category can be deleted after the fact.
      await pumpList(tester, bills: <BillWithStatus>[item(categoryId: null)]);

      expect(find.text('Meralco electricity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('archived bills', () {
    testWidgets('are not in the list', (WidgetTester tester) async {
      // That is what archiving means. The repository is asked without them, and
      // this is what proves the screen does not ask for them anyway.
      await pumpList(
        tester,
        bills: <BillWithStatus>[
          item(),
          item(
            id: 'bill-old',
            name: 'Cancelled gym',
            archivedAt: DateTime(2026, 7, 2),
            status: BillStatus.archived,
          ),
        ],
      );

      expect(find.text('Meralco electricity'), findsOneWidget);
      expect(find.text('Cancelled gym'), findsNothing);
    });
  });
}
