import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/presentation/widgets/app_skeleton.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_detail_provider.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:paypaw/features/dashboard/presentation/widgets/dashboard_cards.dart';
import 'package:paypaw/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';
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
    String? categoryId,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      amount: Money.php(amount),
      dueOn: dueOn,
      categoryId: categoryId,
      archivedAt: archived ? DateTime(2026, 8, 12) : null,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(amount - paid),
    today: DateTime(2026, 9, 3),
  );

  late FakeBillRepository billRepository;

  Future<void> pumpDashboard(
    WidgetTester tester,
    List<BillWithStatus> bills,
  ) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 1600 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    billRepository = FakeBillRepository(bills: bills);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(billRepository),
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

  /// Drags the list down far enough to arm the refresh, then lets it run.
  ///
  /// Stepped by hand rather than through `fling` or `drag`. `RefreshIndicator`
  /// arms by accumulating overscroll across scroll notifications, and both of
  /// those helpers deliver the whole travel in one move — one notification, no
  /// arming, and a test that reports the feature missing when it is present.
  ///
  /// The travel also has to clear a quarter of the viewport, which on this
  /// test's tall view is 400 logical pixels. A shorter drag shows the spinner
  /// and then silently cancels on release — indistinguishable, from the
  /// assertion's side, from no gesture at all.
  Future<void> pullToRefresh(WidgetTester tester) async {
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.byType(DashboardHeader)),
    );

    for (int i = 0; i < 15; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('the headline', () {
    testWidgets('is the total still owed, not the total billed', (
      WidgetTester tester,
    ) async {
      // A partly paid bill contributes its remainder. This is a measure of work
      // left, and counting the settled part would overstate it.
      //
      // One bill overdue, so the total differs from "Upcoming" in the summary
      // card as well as from every row — otherwise the finder cannot tell the
      // headline from the figure that happens to equal it.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.overdue,
          dueOn: DateTime(2026, 8, 20),
          amount: 500000,
          paid: 200000,
          categoryId: 'cat-rent',
        ),
        item(
          id: 'b',
          name: 'Water',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 10, 25),
          categoryId: 'cat-water',
        ),
      ]);

      expect(find.text('TOTAL OUTSTANDING'), findsOneWidget);
      // ₱3,000 left on the first plus ₱1,000 on the second — not the ₱6,000
      // that was billed.
      expect(find.text('₱4,000.00'), findsOneWidget);
      expect(find.text('₱6,000.00'), findsNothing);
    });
  });

  group('the summary card', () {
    testWidgets('splits the total into what is late and what is not', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.overdue,
          dueOn: DateTime(2026, 8, 20),
          amount: 300000,
        ),
        item(
          id: 'b',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('1 bill late'), findsOneWidget);
      expect(find.text('₱3,000.00'), findsWidgets);
    });

    testWidgets('says nothing is late rather than hiding the figure', (
      WidgetTester tester,
    ) async {
      // A grid that changes shape depending on whether anything is overdue makes
      // the reader work out which cell is missing.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 11, 20),
        ),
      ]);

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('0 bills late'), findsOneWidget);
    });

    testWidgets('reports what repeats every month', (
      WidgetTester tester,
    ) async {
      // The one figure on this screen that is not in any bill row, and the one
      // that finally gives the recurring templates a reader.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 20),
        ),
      ]);

      expect(find.text('Every month'), findsOneWidget);
      expect(find.text('nothing repeats'), findsOneWidget);
    });

    testWidgets('and reports paid alongside it', (WidgetTester tester) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Rent',
          status: BillStatus.partiallyPaid,
          dueOn: DateTime(2026, 9, 20),
          amount: 400000,
          paid: 100000,
        ),
      ]);

      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('25% of everything'), findsOneWidget);
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
      final double comingUp = tester
          .getTopLeft(find.text('LATER THIS WEEK'))
          .dy;

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
    // The fixture's today is Thursday 3 September 2026, so this week runs to
    // Sunday the 6th and next week is the 7th to the 13th.
    testWidgets('is grouped by how soon, not listed flat', (
      WidgetTester tester,
    ) async {
      // "Due in 6 days" is a subtraction the reader has to do before they know
      // whether it matters. "Next week" is the answer.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Due now',
          status: BillStatus.dueToday,
          dueOn: DateTime(2026, 9, 3),
        ),
        item(
          id: 'b',
          name: 'Due next',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 4),
        ),
        item(
          id: 'c',
          name: 'Due Saturday',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
        item(
          id: 'd',
          name: 'Due Tuesday',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 8),
        ),
      ]);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('TOMORROW'), findsOneWidget);
      expect(find.text('LATER THIS WEEK'), findsOneWidget);
      expect(find.text('NEXT WEEK'), findsOneWidget);
      expect(find.text('Due Tuesday'), findsOneWidget);
    });

    testWidgets('windows with nothing in them do not appear', (
      WidgetTester tester,
    ) async {
      // An empty heading is a question the reader has to answer for themselves.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Due Saturday',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.text('LATER THIS WEEK'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
      expect(find.text('TOMORROW'), findsNothing);
      expect(find.text('NEXT WEEK'), findsNothing);
    });

    testWidgets('says how many rows are under each heading', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        for (int day = 4; day <= 6; day++)
          item(
            id: 'bill-$day',
            name: 'Bill $day',
            status: BillStatus.dueSoon,
            dueOn: DateTime(2026, 9, day),
          ),
      ]);

      // One under "tomorrow", two under "later this week".
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('counts what is past next week instead of listing it', (
      WidgetTester tester,
    ) async {
      // A row per bill six weeks out turns the dashboard into the bills list.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Far off',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 9, 20),
          amount: 150000,
        ),
        item(
          id: 'b',
          name: 'Further off',
          status: BillStatus.upcoming,
          dueOn: DateTime(2026, 10, 25),
          amount: 250000,
        ),
      ]);

      expect(find.text('Far off'), findsNothing);
      expect(find.text('2 more bills later'), findsOneWidget);
      // The date matters most here: when everything falls past next week this
      // row is all the user has, and a count with no anchor says nothing about
      // whether later means Tuesday or March.
      expect(find.text('₱4,000.00 · from Sep 20'), findsOneWidget);
    });

    testWidgets('soonest first inside a window', (WidgetTester tester) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'b',
          name: 'Later',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 6),
        ),
        item(
          id: 'a',
          name: 'Sooner',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
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
      // Sprint 37's list also names "Add debt" and "Add subscription". Debts are
      // Phase 11 and subscriptions are Phase 10, so neither has anywhere to go —
      // and a row where two of five do nothing teaches the user that the row is
      // decoration.
      await pumpDashboard(tester, const <BillWithStatus>[]);

      expect(find.text('Add bill'), findsWidgets);
      expect(find.text('All bills'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Add debt'), findsNothing);
      expect(find.text('Add subscription'), findsNothing);
    });

    testWidgets('offers Mark paid once there is something to pay', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.text('Mark paid'), findsOneWidget);
    });

    testWidgets('and hides it when nothing is outstanding', (
      WidgetTester tester,
    ) async {
      // The same rule as the two unbuilt actions, applied per-user: an entry
      // point that opens onto an empty sheet is the same broken promise as one
      // with nothing behind it.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.paid,
          dueOn: DateTime(2026, 9, 5),
        ),
        item(
          id: 'b',
          name: 'Put away',
          status: BillStatus.archived,
          dueOn: DateTime(2026, 9, 6),
          archived: true,
        ),
      ]);

      expect(find.text('Mark paid'), findsNothing);
    });

    testWidgets('and asks which bill before recording anything', (
      WidgetTester tester,
    ) async {
      // The dashboard has no bill in hand, unlike the detail drawer. Late first,
      // because the bill somebody just paid is the one that was worrying them.
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

      await tester.tap(find.text('Mark paid'));
      await tester.pumpAndSettle();

      expect(find.text('Which bill did you pay?'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Rent').last).dy,
        lessThan(tester.getTopLeft(find.text('Water').last).dy),
      );
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

    test('names the person by their own name when they have given one', () {
      expect(
        DashboardHeader.nameOrAddress(name: 'Marc', email: 'x@example.com'),
        'Marc',
      );
      expect(UserProfile.initialFor(name: 'Marc', email: 'x@example.com'), 'M');
    });

    test('and by the local part of their address when they have not', () {
      // A header is an identity, not a credential — and the local part is a
      // login rather than a name, which is why it is only the fallback.
      expect(DashboardHeader.nameOrAddress(email: 'marc@example.com'), 'marc');
      expect(UserProfile.initialFor(email: 'marc@example.com'), 'M');
    });

    test('a name of nothing but spaces is not a name', () {
      expect(
        DashboardHeader.nameOrAddress(name: '   ', email: 'marc@example.com'),
        'marc',
      );
    });

    test('and it falls back rather than showing an empty line', () {
      expect(DashboardHeader.nameOrAddress(), 'Welcome back');
      expect(DashboardHeader.nameOrAddress(email: ''), 'Welcome back');
      expect(
        DashboardHeader.nameOrAddress(email: '@nothing.com'),
        'Welcome back',
      );
      expect(UserProfile.initialFor(), '?');
    });
  });

  group('while it is loading', () {
    testWidgets('stands in for the shape of what is coming', (
      WidgetTester tester,
    ) async {
      // Three plain rectangles said "something is loading" and nothing else, so
      // the screen jumped when the data landed. A skeleton exists to stop that
      // jump — otherwise a spinner would do, and cost less.
      await pumpDashboard(tester, const <BillWithStatus>[]);
      billRepository.blockFetch();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      container.invalidate(billsProvider);
      await tester.pump();

      // The header is real before the bills are, and never waits.
      expect(find.byType(DashboardHeader), findsOneWidget);

      billRepository.releaseFetch();
      await tester.pumpAndSettle();
    });

    testWidgets('and never replaces figures it already has', (
      WidgetTester tester,
    ) async {
      // The defect this exists for: a refresh is *also* AsyncLoading, with the
      // previous value still attached. Matching on that first meant recording a
      // payment blanked the whole screen back to placeholders — the user's own
      // action looking like the app losing its place.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
          amount: 150000,
        ),
      ]);

      expect(find.text('₱1,500.00'), findsWidgets);

      billRepository.blockFetch();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(DashboardScreen)),
      );
      container.invalidate(billsProvider);
      await tester.pump();

      // Mid-refresh, and the figures are still on screen.
      expect(find.byType(AppSkeleton), findsNothing);
      expect(find.text('₱1,500.00'), findsWidgets);
      expect(find.text('Water'), findsOneWidget);

      billRepository.releaseFetch();
      await tester.pumpAndSettle();
    });
  });

  group('refreshing', () {
    testWidgets('is possible at all', (WidgetTester tester) async {
      // Before this the only way to ask for fresh figures was to kill the app,
      // on the screen a user opens specifically to check on something.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
        ),
      ]);

      expect(find.byType(RefreshIndicator), findsOneWidget);
      final int before = billRepository.fetchCalls;

      await pullToRefresh(tester);

      expect(billRepository.fetchCalls, greaterThan(before));
    });

    testWidgets('even with almost nothing on the screen to pull', (
      WidgetTester tester,
    ) async {
      // A dashboard with two bills does not fill the viewport, and that is
      // exactly when someone wonders whether the figures are current. Without
      // AlwaysScrollableScrollPhysics the gesture has nowhere to travel.
      await pumpDashboard(tester, const <BillWithStatus>[]);

      final int before = billRepository.fetchCalls;

      await pullToRefresh(tester);

      expect(billRepository.fetchCalls, greaterThan(before));
    });
  });

  group('the figures that move', () {
    testWidgets('land on their value rather than counting up to it', (
      WidgetTester tester,
    ) async {
      // A total that counts from zero on every launch is a loading animation
      // pretending to be information — it withholds the one number the reader
      // opened the screen for.
      await pumpDashboard(tester, <BillWithStatus>[
        item(
          id: 'a',
          name: 'Water',
          status: BillStatus.dueSoon,
          dueOn: DateTime(2026, 9, 5),
          amount: 150000,
        ),
      ]);

      // Scoped to the animated widget itself. The money card legitimately shows
      // ₱0.00 for overdue and paid, so a bare finder proves nothing about the
      // figure that animates.
      expect(
        find.descendant(
          of: find.byType(AnimatedMoney),
          matching: find.text('₱1,500.00'),
        ),
        findsOneWidget,
      );
    });
  });
}
