import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/screens/edit_bill_screen.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';

import '../helpers/fake_bill_repository.dart';

/// Editing a bill.
///
/// The form itself is covered by the add-bill suite — it is the same widget. What
/// is different here, and what these tests are about: the fields arrive filled,
/// the update carries the parts of the row the form never shows, and clearing an
/// optional field actually clears it.
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

  /// A stored bill with every optional field filled, so a test can check that
  /// emptying one is a real change rather than a no-op.
  Bill stored({
    String? categoryId = 'cat-electricity',
    String? payee = 'Meralco',
    String? notes = 'account 1234',
  }) => Bill(
    id: 'bill-1',
    userId: 'user-1',
    name: 'Meralco electricity',
    payee: payee,
    amount: const Money.php(245050),
    dueOn: DateTime(2026, 9, 5),
    categoryId: categoryId,
    // The form never shows this. It has to survive an edit anyway, or a
    // generated occurrence loses its link to the template that made it.
    recurringBillId: 'recurring-7',
    notes: notes,
    createdAt: DateTime(2026, 8, 2),
    updatedAt: DateTime(2026, 8, 2),
  );

  BillWithStatus withStatus(Bill bill) => BillWithStatus(
    bill: bill,
    status: BillStatus.dueSoon,
    paid: const Money.php(0),
    outstanding: bill.amount,
    today: DateTime(2026, 9, 3),
  );

  late FakeBillRepository repository;

  Future<void> pumpEdit(
    WidgetTester tester, {
    Bill? bill,
    String openId = 'bill-1',
  }) async {
    repository = FakeBillRepository(
      bills: bill == null
          ? const <BillWithStatus>[]
          : <BillWithStatus>[withStatus(bill)],
    );

    // Tall enough that the whole form is built: it is a ListView, so a button
    // below the fold does not exist to be tapped.
    tester.view
      ..physicalSize = const Size(392 * 3, 1500 * 3)
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
            initialLocation: '/bills/$openId/edit',
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.bills.path,
                name: AppRoutes.bills.routeName,
                builder: (_, _) => const Scaffold(body: Text('bills stub')),
              ),
              GoRoute(
                path: AppRoutes.editBill.path,
                name: AppRoutes.editBill.routeName,
                builder: (_, GoRouterState state) =>
                    EditBillScreen(billId: state.pathParameters['id']!),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(TextFormField),
  );

  Future<void> saveChanges(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
  }

  group('opening it', () {
    testWidgets('the fields arrive filled', (WidgetTester tester) async {
      await pumpEdit(tester, bill: stored());

      expect(find.text('Meralco electricity'), findsWidgets);
      // Formatted the way the amount field formats, so saving without touching
      // anything is not an edit.
      expect(find.text('2,450.50'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('account 1234'), findsOneWidget);
    });

    testWidgets('the button says what it does', (WidgetTester tester) async {
      // 'Save bill' on a bill that already exists reads as making a second one.
      await pumpEdit(tester, bill: stored());

      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Save bill'), findsNothing);
    });

    testWidgets('a bill that is not there says so, without saying why', (
      WidgetTester tester,
    ) async {
      // Deleted and belongs-to-someone-else are the same answer under RLS, and
      // have to stay the same answer.
      await pumpEdit(tester, openId: 'missing');

      expect(find.text('Bill not found'), findsOneWidget);
    });
  });

  group('saving changes', () {
    testWidgets('sends the edited fields', (WidgetTester tester) async {
      await pumpEdit(tester, bill: stored());

      await tester.enterText(field('Bill name'), 'Meralco — main meter');
      await tester.enterText(field('Amount'), '3000');
      await tester.pump();

      await saveChanges(tester);

      expect(repository.updated!.name, 'Meralco — main meter');
      expect(repository.updated!.amount, const Money.php(300000));
    });

    testWidgets('keeps the parts of the row the form never shows', (
      WidgetTester tester,
    ) async {
      // The id, the owner and the recurrence link. Rebuilding a Bill from the
      // form's six fields alone would drop the link and orphan the occurrence
      // from the template that generated it.
      await pumpEdit(tester, bill: stored());

      await tester.enterText(field('Bill name'), 'Renamed');
      await tester.pump();
      await saveChanges(tester);

      expect(repository.updated!.id, 'bill-1');
      expect(repository.updated!.userId, 'user-1');
      expect(repository.updated!.recurringBillId, 'recurring-7');
      expect(repository.updated!.createdAt, DateTime(2026, 8, 2));
    });

    testWidgets('an unchanged form sends what was already there', (
      WidgetTester tester,
    ) async {
      // The round trip that matters: prefill, save, and the row is identical.
      // If `formatBare` and `Money.tryParse` disagreed about commas this would
      // change the amount.
      await pumpEdit(tester, bill: stored());

      await saveChanges(tester);

      expect(repository.updated!.amount, const Money.php(245050));
      expect(repository.updated!.name, 'Meralco electricity');
      expect(repository.updated!.payee, 'Meralco');
      expect(repository.updated!.notes, 'account 1234');
      expect(repository.updated!.categoryId, 'cat-electricity');
      expect(repository.updated!.dueOn, DateTime(2026, 9, 5));
    });
  });

  group('clearing an optional field', () {
    testWidgets('emptying the notes really empties them', (
      WidgetTester tester,
    ) async {
      // The bug this guards: `copyWith(notes: null)` means "leave it alone", so
      // a naive implementation silently keeps the old note. `clearing` is what
      // makes removal expressible, and this is what proves it is being used.
      await pumpEdit(tester, bill: stored());

      await tester.enterText(field('Notes'), '');
      await tester.pump();
      await saveChanges(tester);

      expect(repository.updated!.notes, isNull);
    });

    testWidgets('and so does emptying the payee', (WidgetTester tester) async {
      await pumpEdit(tester, bill: stored());

      await tester.enterText(field('Paid to'), '   ');
      await tester.pump();
      await saveChanges(tester);

      expect(repository.updated!.payee, isNull);
    });

    testWidgets('removing the category removes it', (
      WidgetTester tester,
    ) async {
      await pumpEdit(tester, bill: stored());

      await tester.tap(find.byTooltip('Clear category'));
      await tester.pumpAndSettle();
      await saveChanges(tester);

      expect(repository.updated!.categoryId, isNull);
    });
  });

  group('when the update fails', () {
    testWidgets('the message is shown and the edits are kept', (
      WidgetTester tester,
    ) async {
      await pumpEdit(tester, bill: stored());
      repository.failure = const NetworkException();

      await tester.enterText(field('Bill name'), 'Renamed');
      await tester.pump();
      await saveChanges(tester);

      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.text('Renamed'), findsOneWidget);
    });

    testWidgets('and it can be retried', (WidgetTester tester) async {
      await pumpEdit(tester, bill: stored());
      repository.failure = const NetworkException();

      await saveChanges(tester);
      repository.failure = null;
      await saveChanges(tester);

      expect(repository.updateCalls, 2);
      expect(repository.updated, isNotNull);
    });
  });
}
