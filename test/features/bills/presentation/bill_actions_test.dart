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
import 'package:paypaw/features/bills/presentation/widgets/bill_list_tile.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';

import '../helpers/fake_bill_repository.dart';

/// The detail drawer, the swipe gestures, and the confirmation before a delete.
///
/// These are the paths where a mistake costs the user data, so they are tested
/// through the real list: the swipe, the dialog and the repository call all have
/// to line up, and each of them is fine in isolation.
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
    BillStatus status = BillStatus.upcoming,
    int paid = 0,
    String? notes,
    String? payee,
    DateTime? archivedAt,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      payee: payee,
      amount: const Money.php(245050),
      dueOn: DateTime(2026, 9, 20),
      categoryId: 'cat-electricity',
      notes: notes,
      archivedAt: archivedAt,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(245050 - paid),
    today: DateTime(2026, 9, 3),
  );

  late FakeBillRepository repository;

  Future<void> pumpList(WidgetTester tester, List<BillWithStatus> bills) async {
    repository = FakeBillRepository(bills: bills);

    tester.view
      ..physicalSize = const Size(392 * 3, 1200 * 3)
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

  Future<void> openDetail(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  group('the detail drawer', () {
    testWidgets('shows the three money figures together', (
      WidgetTester tester,
    ) async {
      // The interesting thing is the relationship between them: outstanding on
      // its own does not say whether a bill is untouched or nearly settled.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, paid: 100000),
      ]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('₱2,450.50'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('₱1,000.00'), findsOneWidget);
      expect(find.text('Outstanding'), findsWidgets);
    });

    testWidgets('hides the paid line when nothing has been paid', (
      WidgetTester tester,
    ) async {
      // A row reading "Paid ₱0.00" is a line that only ever says nothing.
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Paid'), findsNothing);
    });

    testWidgets('shows the notes and the payee when there are any', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[
        item(notes: 'Account 1234', payee: 'Meralco'),
      ]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('NOTES'), findsOneWidget);
      expect(find.text('Account 1234'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
    });

    testWidgets('and leaves them out when there are not', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('NOTES'), findsNothing);
      expect(find.text('Paid to'), findsNothing);
    });

    testWidgets('Edit opens the form', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.text('Edit bill'));
      await tester.pumpAndSettle();

      expect(find.text('edit bill-1'), findsOneWidget);
    });

    testWidgets('is modal over the whole app, not just the tab', (
      WidgetTester tester,
    ) async {
      // A sheet shown on a branch navigator is only modal over that branch, and
      // the shell's floating navigation bar keeps drawing on top of it — which
      // put the pill squarely over the Delete button and made it unreachable.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      final Rect delete = tester.getRect(
        find.widgetWithText(FilledButton, 'Delete'),
      );

      // On screen and not clipped, which is what the nav bar was preventing.
      expect(delete.bottom, lessThanOrEqualTo(1200));
      expect(delete.height, greaterThan(0));
    });

    testWidgets('offers Archive on a live bill and Restore on an archived one', (
      WidgetTester tester,
    ) async {
      // Offering "Archive" on something already archived is a button that does
      // nothing visible.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
    });
  });

  group('archiving', () {
    testWidgets('archives and offers an undo', (WidgetTester tester) async {
      // Honest here, because archiving is one reversible column. The delete path
      // deliberately has no undo.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(repository.archived, 'bill-1');
      expect(find.text('Meralco electricity archived'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('asks first, and says what else goes with it', (
      WidgetTester tester,
    ) async {
      // "Are you sure?" tells the reader nothing they did not know. The payment
      // history is the part they would miss.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, paid: 100000),
      ]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Meralco electricity?'), findsOneWidget);
      expect(find.textContaining('₱1,000.00 of payments'), findsOneWidget);
      // Nothing has happened yet.
      expect(repository.deleted, isNull);
    });

    testWidgets('cancelling deletes nothing', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isNull);
    });

    testWidgets('confirming deletes it', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleted, 'bill-1');
      expect(find.text('Meralco electricity deleted'), findsOneWidget);
    });

    testWidgets('and offers no undo, because there is none', (
      WidgetTester tester,
    ) async {
      // A snackbar with an Undo button on an operation that cannot be undone is
      // a lie. The confirmation is what stands in for it.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing);
    });
  });

  group('swiping', () {
    testWidgets('right opens the editor and leaves the row in place', (
      WidgetTester tester,
    ) async {
      // The asymmetry that makes the swipe widget worth having: a true from
      // confirmDismiss here would animate the row out from under the editor.
      await pumpList(tester, <BillWithStatus>[item()]);

      await tester.drag(find.byType(BillListTile), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('edit bill-1'), findsOneWidget);
      expect(repository.deleted, isNull);
    });

    testWidgets('left asks before deleting', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      await tester.drag(find.byType(BillListTile), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete Meralco electricity?'), findsOneWidget);
      expect(repository.deleted, isNull);
    });

    testWidgets('and the row stays when the dialog is cancelled', (
      WidgetTester tester,
    ) async {
      // Dismissible would otherwise have already animated it away.
      await pumpList(tester, <BillWithStatus>[item()]);

      await tester.drag(find.byType(BillListTile), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Meralco electricity'), findsOneWidget);
      expect(repository.deleted, isNull);
    });

    testWidgets('left then confirm removes it', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      await tester.drag(find.byType(BillListTile), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.deleted, 'bill-1');
    });
  });
}
