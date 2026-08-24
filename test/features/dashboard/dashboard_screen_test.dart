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
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:paypaw/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../bills/helpers/fake_bill_repository.dart';
import '../payments/helpers/fake_payment_repository.dart';
import '../recurring/helpers/fake_recurring_bill_repository.dart';

/// The dashboard's structure.
///
/// What Sprint 34 is responsible for: the blocks are present, they carry real
/// figures, and each one is absent when it has nothing to say. The depth of each
/// block arrives in Sprints 35 to 38.
void main() {
  BillWithStatus item({
    required String id,
    required String name,
    required BillStatus status,
    required DateTime dueOn,
    int amount = 100000,
    int paid = 0,
    bool archived = false,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      amount: Money.php(amount),
      dueOn: dueOn,
      archivedAt: archived ? DateTime(2026, 8, 12) : null,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(amount - paid),
    today: DateTime(2026, 9, 3),
  );

  Future<void> pumpDashboard(
    WidgetTester tester,
    List<BillWithStatus> bills,
  ) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 1600 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(
            FakeBillRepository(bills: bills),
          ),
          recurringBillRepositoryProvider.overrideWithValue(
            FakeRecurringBillRepository(),
          ),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
          categoriesProvider.overrideWith(
            (Ref ref) => Future<List<Category>>.value(const <Category>[]),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.dashboard.path,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.dashboard.path,
                name: AppRoutes.dashboard.routeName,
                builder: (_, _) => const DashboardScreen(),
              ),
              GoRoute(
                path: AppRoutes.bills.path,
                name: AppRoutes.bills.routeName,
                builder: (_, _) => const Scaffold(body: Text('bills stub')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the headline', () {
    testWidgets('is the total still owed, not the total billed', (
      WidgetTester tester,
    ) async {
      // A partly paid bill contributes its remainder. This is a measure of work
      // left, and counting the settled part would overstate it.
      //
      // Two bills, so the total matches no single row — otherwise the finder
      // cannot tell the headline from the row that happens to equal it.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.partiallyPaid,
          dueOn: DateTime(2026, 9, 20),
          amount: 500000,
          paid: 200000,
        ),
        item(
          id: 'b',
          name: 'Water',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 25),
        ),
      ]);

      expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
      // ₱3,000 left on the first plus ₱1,000 on the second — not the ₱6,000
      // that was billed.
      expect(find.text('₱4,000.00'), findsOneWidget);
      expect(find.text('₱6,000.00'), findsNothing);
    });

    testWidgets('breaks the figure down only where there is a breakdown', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.overdue,
          dueOn: DateTime(2026, 8, 20),
        ),
        item(
          id: 'b',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.text('1 overdue'), findsOneWidget);
      expect(find.text('1 due soon'), findsOneWidget);
    });

    testWidgets('and says so plainly when nothing is pressing', (
      WidgetTester tester,
    ) async {
      // An empty row of chips under the figure would read as something failing
      // to load.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 11, 20),
        ),
      ]);

      expect(find.text('Nothing due yet'), findsOneWidget);
      expect(find.textContaining('overdue'), findsNothing);
    });
  });

  group('overdue', () {
    testWidgets('comes above what is coming up', (WidgetTester tester) async {
      // Something already late outranks something that has not happened yet.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
        item(
          id: 'b',
          name: 'Rent',
          status: BillStatus.overdue,
          dueOn: DateTime(2026, 8, 20),
        ),
      ]);

      final double needsPaying = tester
          .getTopLeft(find.text('NEEDS PAYING NOW'))
          .dy;
      final double comingUp = tester.getTopLeft(find.text('COMING UP')).dy;

      expect(needsPaying, lessThan(comingUp));
    });

    testWidgets('is absent entirely when nothing is late', (
      WidgetTester tester,
    ) async {
      // A heading over nothing is a small daily untruth.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.text('NEEDS PAYING NOW'), findsNothing);
    });
  });

  group('coming up', () {
    testWidgets('shows only the next few, and offers the rest', (
      WidgetTester tester,
    ) async {
      // This screen answers "what needs me today". The bills list already answers
      // "show me everything", and two tabs showing the same rows are one tab and
      // a wasted tap.
      await pumpDashboard(tester, <BillWithStatus>[
        for (int day = 5; day <= 12; day++)
          item(
            id: 'bill-$day',
            name: 'Bill $day',
            status: BillStatus.upcoming,
            dueOn: DateTime(2026, 9, day),
          ),
      ]);

      expect(find.text('Bill 5'), findsOneWidget);
      expect(find.text('Bill 7'), findsOneWidget);
      // The fourth onwards is behind "See all".
      expect(find.text('Bill 8'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('and does not offer "See all" when nothing is held back', (
      WidgetTester tester,
    ) async {
      // A link to the screen you are already looking at.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 6),
        ),
      ]);

      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
    });

    testWidgets('soonest first', (WidgetTester tester) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'b',
          name: 'Later',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 25),
        ),
        item(
          id: 'a',
          name: 'Sooner',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 6),
        ),
      ]);

      expect(
        tester.getTopLeft(find.text('Sooner')).dy,
        lessThan(tester.getTopLeft(find.text('Later')).dy),
      );
    });

    testWidgets('leaves out settled and archived bills', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Settled one',
          status: BillStatus.paid,
          dueOn: DateTime(2026, 9, 6),
        ),
        item(
          id: 'b',
          name: 'Put away',
          status: BillStatus.archived,
          dueOn: DateTime(2026, 9, 7),
          archived: true,
        ),
      ]);

      expect(find.text('Settled one'), findsNothing);
      expect(find.text('Put away'), findsNothing);
    });

    testWidgets('says everything is clear rather than showing nothing', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Settled one',
          status: BillStatus.paid,
          dueOn: DateTime(2026, 9, 6),
        ),
      ]);

      expect(find.textContaining('Nothing coming up'), findsOneWidget);
    });
  });

  group('with no bills at all', () {
    testWidgets('offers the one thing worth doing', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, const <BillWithStatus>[]);

      expect(find.text('No bills yet'), findsOneWidget);
      expect(find.text('₱0.00'), findsOneWidget);
    });
  });

  group('quick actions', () {
    testWidgets('only offers what actually works', (WidgetTester tester) async {
      // Sprint 37's list includes marking a bill paid and adding a debt, neither
      // of which exists. A row where two of five do nothing teaches the user that
      // the row is decoration.
      await pumpDashboard(tester, const <BillWithStatus>[]);

      expect(find.text('Add bill'), findsWidgets);
      expect(find.text('All bills'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Mark paid'), findsNothing);
      expect(find.text('Add debt'), findsNothing);
    });
  });

  group('the greeting', () {
    test('follows the hour, and three in the morning is still evening', () {
      // Somebody up at three has not started their day.
      expect(DashboardHeader.greeting(DateTime(2026, 9, 3, 3)), 'Good evening');
      expect(DashboardHeader.greeting(DateTime(2026, 9, 3, 5)), 'Good morning');
      expect(
        DashboardHeader.greeting(DateTime(2026, 9, 3, 11)),
        'Good morning',
      );
      expect(
        DashboardHeader.greeting(DateTime(2026, 9, 3, 12)),
        'Good afternoon',
      );
      expect(
        DashboardHeader.greeting(DateTime(2026, 9, 3, 17)),
        'Good afternoon',
      );
      expect(
        DashboardHeader.greeting(DateTime(2026, 9, 3, 18)),
        'Good evening',
      );
      expect(
        DashboardHeader.greeting(DateTime(2026, 9, 3, 23)),
        'Good evening',
      );
    });

    test('names the person by the local part of their address', () {
      // A header is an identity, not a credential.
      expect(DashboardHeader.displayName('marc@example.com'), 'marc');
      expect(DashboardHeader.initial('marc@example.com'), 'M');
    });

    test('and falls back rather than showing an empty line', () {
      expect(DashboardHeader.displayName(null), 'Welcome back');
      expect(DashboardHeader.displayName(''), 'Welcome back');
      expect(DashboardHeader.displayName('@nothing.com'), 'Welcome back');
      expect(DashboardHeader.initial(null), 'W');
    });
  });
}
