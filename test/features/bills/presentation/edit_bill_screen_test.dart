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
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../../recurring/helpers/fake_recurring_bill_repository.dart';
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
    String? recurringBillId = 'recurring-7',
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
    recurringBillId: recurringBillId,
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
  late FakeRecurringBillRepository recurring;

  Future<void> pumpEdit(
    WidgetTester tester, {
    Bill? bill,
    String openId = 'bill-1',
    List<RecurringBill> templates = const <RecurringBill>[],
  }) async {
    repository = FakeBillRepository(
      bills: bill == null
          ? const <BillWithStatus>[]
          : <BillWithStatus>[withStatus(bill)],
    );
    recurring = FakeRecurringBillRepository(templates: templates);

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
          recurringBillRepositoryProvider.overrideWithValue(recurring),
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

  /// The schedule `stored()` points at.
  RecurringBill schedule({bool isActive = true, int dayOfMonth = 5}) =>
      RecurringBill(
        id: 'recurring-7',
        userId: 'user-1',
        kind: RecurringBillKind.bill,
        name: 'Meralco electricity',
        amount: const Money.php(245050),
        recurrence: Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: dayOfMonth,
          startsOn: DateTime(2026, 8, 2),
        ),
        nextDueOn: DateTime(2026, 10, 5),
        isActive: isActive,
        createdAt: DateTime(2026, 8, 2),
        updatedAt: DateTime(2026, 8, 2),
      );

  group('opening it', () {
    testWidgets('shows the schedule the bill already belongs to', (
      WidgetTester tester,
    ) async {
      // Not "Does not repeat". The field claiming a repeating bill was one-off
      // meant saving anything at all silently stopped the schedule.
      await pumpEdit(
        tester,
        bill: stored(),
        templates: <RecurringBill>[schedule()],
      );

      expect(find.text('Every month on the 5th'), findsOneWidget);
    });

    testWidgets('waits for it rather than showing the wrong answer first', (
      WidgetTester tester,
    ) async {
      // Building before the template arrives shows "Does not repeat" and then
      // flips — and anyone who saved in that moment would have cancelled a
      // schedule without meaning to.
      await pumpEdit(
        tester,
        bill: stored(),
        templates: <RecurringBill>[schedule()],
      );

      expect(find.text('Does not repeat'), findsNothing);
    });

    testWidgets('a bill with no schedule says so', (WidgetTester tester) async {
      await pumpEdit(tester, bill: stored(recurringBillId: null));

      expect(find.text('Does not repeat'), findsOneWidget);
    });

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

  group('changing whether it repeats', () {
    /// Opens the Repeat editor and accepts whatever it defaults to.
    Future<void> setRepeat(WidgetTester tester, String from) async {
      await tester.tap(find.text(from));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('turning it on creates a schedule and joins this bill to it', (
      WidgetTester tester,
    ) async {
      await pumpEdit(tester, bill: stored(recurringBillId: null));

      await setRepeat(tester, 'Does not repeat');
      await saveChanges(tester);

      expect(recurring.created, isNotNull);
      // The bill is linked, so it counts as the schedule's occurrence rather
      // than sitting beside one.
      expect(repository.updated!.recurringBillId, 'rec-new');
    });

    testWidgets('and the schedule starts after this bill, not on it', (
      WidgetTester tester,
    ) async {
      // The bill is due 5 September and the default rule is monthly on the 5th.
      // A bookmark of 5 September would have the generator create a second bill
      // for a date this one already covers.
      await pumpEdit(tester, bill: stored(recurringBillId: null));

      await setRepeat(tester, 'Does not repeat');
      await saveChanges(tester);

      expect(recurring.created!.nextDueOn, DateTime(2026, 10, 5));
    });

    testWidgets('turning it off stops the schedule rather than deleting it', (
      WidgetTester tester,
    ) async {
      // Deleting would null out `recurring_bill_id` on every bill it produced —
      // `on delete set null` — and the record that those months came from a
      // schedule is worth more than the row.
      await pumpEdit(
        tester,
        bill: stored(),
        templates: <RecurringBill>[schedule()],
      );

      await tester.tap(find.text('Every month on the 5th'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Does not repeat'));
      await tester.pumpAndSettle();
      await saveChanges(tester);

      expect(recurring.updated!.isActive, isFalse);
      expect(recurring.deleted, isNull);
    });

    testWidgets('changing the rule moves the bookmark past this bill', (
      WidgetTester tester,
    ) async {
      // Everything up to and including the bill being edited already exists.
      await pumpEdit(
        tester,
        bill: stored(),
        templates: <RecurringBill>[schedule()],
      );

      await tester.tap(find.text('Every month on the 5th'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await saveChanges(tester);

      expect(
        recurring.updated!.recurrence.frequency,
        RecurrenceFrequency.quarterly,
      );
      // November, not December. A quarterly rule steps from the month it starts
      // in — August here — so its occurrences are Aug, Nov, Feb. Anchoring on the
      // bill being edited instead would silently shift the whole schedule.
      expect(recurring.updated!.nextDueOn, DateTime(2026, 11, 5));
    });

    testWidgets('leaving it alone changes no schedule', (
      WidgetTester tester,
    ) async {
      // Opening a repeating bill, renaming it and saving must not touch the rule.
      await pumpEdit(
        tester,
        bill: stored(),
        templates: <RecurringBill>[schedule()],
      );

      await tester.enterText(field('Bill name'), 'Renamed');
      await tester.pump();
      await saveChanges(tester);

      expect(recurring.updated!.recurrence, schedule().recurrence);
      expect(recurring.updated!.isActive, isTrue);
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
