import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/screens/add_bill_screen.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../../recurring/helpers/fake_recurring_bill_repository.dart';
import '../helpers/fake_bill_repository.dart';

void main() {
  const List<Category> categories = <Category>[
    Category(
      id: 'cat-electricity',
      name: 'Electricity',
      iconName: 'bolt',
      colorHex: '#F59E0B',
      sortOrder: 10,
    ),
    Category(
      id: 'cat-water',
      name: 'Water',
      iconName: 'water_drop',
      colorHex: '#3B82F6',
      sortOrder: 20,
    ),
  ];

  late FakeBillRepository repository;
  late FakeRecurringBillRepository recurring;

  setUp(() {
    repository = FakeBillRepository();
    recurring = FakeRecurringBillRepository();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    List<Category> available = categories,
  }) async {
    // Tall enough that the whole form is built. It is a ListView, so a button
    // below the fold does not exist to be tapped — and an inline error banner is
    // exactly what pushes it there, which made the failure cases fail for a
    // reason that had nothing to do with what they were testing. Real phone
    // sizes are covered by the layout test at the bottom of this file.
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
            (Ref ref) => Future<List<Category>>.value(available),
          ),
        ],
        // A router, because the screen closes itself on success and `canPop`
        // needs one. A stub for Bills so there is somewhere to close *to* —
        // which is also how the test can tell that it left.
        child: MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: GoRouter(
            initialLocation: AppRoutes.addBill.path,
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.bills.path,
                name: AppRoutes.bills.routeName,
                builder: (_, _) => const Scaffold(body: Text('bills stub')),
              ),
              GoRoute(
                path: AppRoutes.addBill.path,
                name: AppRoutes.addBill.routeName,
                builder: (_, _) => const AddBillScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// `AppTextField` renders its label as a sibling above the input, not inside
  /// it, so the label has to be climbed out of before the field can be found.
  Finder field(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(AppTextField),
    ),
    matching: find.byType(TextFormField),
  );

  Future<void> fillRequired(WidgetTester tester) async {
    await tester.enterText(field('Bill name'), 'Meralco electricity');
    await tester.enterText(field('Amount'), '1250.50');
    await tester.pump();

    // The date comes from the platform picker, so it has to be tapped through.
    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save bill'));
    await tester.pumpAndSettle();
  }

  group('what the form asks for', () {
    testWidgets('three required fields and three optional ones', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);

      expect(find.text('Bill name'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('Due date'), findsOneWidget);

      // Optional, and it has to say so — otherwise every field reads as
      // mandatory and the form looks longer than it is.
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('optional'), findsOneWidget);
      expect(find.text('Paid to'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('the date starts empty, and looks empty', (
      WidgetTester tester,
    ) async {
      // A placeholder styled like a value makes an unfilled field read as
      // filled, which is how a form gets submitted half-done.
      await pumpForm(tester);

      expect(find.text('Pick a date'), findsOneWidget);
    });
  });

  group('validation', () {
    testWidgets('an empty form does not submit', (WidgetTester tester) async {
      await pumpForm(tester);

      await save(tester);

      expect(repository.createCalls, 0);
    });

    testWidgets('and says what is wrong with every field at once', (
      WidgetTester tester,
    ) async {
      // Both checks run before returning, so a form with two problems shows
      // two, rather than one at a time on successive taps.
      await pumpForm(tester);

      await save(tester);

      expect(find.text('Give this bill a name'), findsOneWidget);
      expect(find.text('Enter the amount'), findsOneWidget);
      expect(find.text('Choose a due date'), findsOneWidget);
    });

    testWidgets('the date error waits until the first attempt', (
      WidgetTester tester,
    ) async {
      // Telling someone off for a field they have not reached is nagging. The
      // Form's own fields get this from autovalidateMode; the date picker is not
      // one of them, so it needs the flag — and the flag needs a test.
      await pumpForm(tester);

      expect(find.text('Choose a due date'), findsNothing);
    });

    testWidgets('a zero amount is refused, unlike the column', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);
      await tester.enterText(field('Bill name'), 'Meralco');
      await tester.enterText(field('Amount'), '0');
      await tester.pump();

      await save(tester);

      expect(repository.createCalls, 0);
    });
  });

  group('saving', () {
    testWidgets('sends what was typed', (WidgetTester tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      expect(repository.created, isNotNull);
      expect(repository.created!.name, 'Meralco electricity');
      // Minor units, exactly. 1250.50 through a double would be 125049.999…
      expect(repository.created!.amount, const Money.php(125050));
    });

    testWidgets('the due date is a date, with no time on it', (
      WidgetTester tester,
    ) async {
      // The picker hands back midnight already, but a value normalised in one
      // place is a value that cannot arrive with a stray time from somewhere
      // else.
      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      final DateTime dueOn = repository.created!.dueOn;

      expect(dueOn.hour, 0);
      expect(dueOn.minute, 0);
      expect(dueOn.second, 0);
    });

    testWidgets('an untouched optional field is null, not an empty string', (
      WidgetTester tester,
    ) async {
      // A blank payee means "no payee" — a null column. An empty string would
      // format later as a stray blank line on the detail screen.
      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      expect(repository.created!.payee, isNull);
      expect(repository.created!.notes, isNull);
      expect(repository.created!.categoryId, isNull);
    });

    testWidgets('whitespace counts as untouched', (WidgetTester tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      await tester.enterText(field('Paid to'), '   ');
      await tester.pump();

      await save(tester);

      expect(repository.created!.payee, isNull);
    });

    testWidgets('the name is trimmed', (WidgetTester tester) async {
      await pumpForm(tester);
      await tester.enterText(field('Bill name'), '  Meralco  ');
      await tester.enterText(field('Amount'), '100');
      await tester.pump();
      await tester.tap(find.text('Pick a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await save(tester);

      expect(repository.created!.name, 'Meralco');
    });

    testWidgets('it confirms, then leaves', (WidgetTester tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      // Saving something and being returned with no acknowledgement reads as
      // having lost it.
      expect(find.textContaining('saved'), findsOneWidget);
    });
  });

  group('the category picker', () {
    testWidgets('opens a sheet and records the choice', (
      WidgetTester tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();

      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);

      await tester.tap(find.text('Electricity'));
      await tester.pumpAndSettle();

      await fillRequired(tester);
      await save(tester);

      expect(repository.created!.categoryId, 'cat-electricity');
    });

    testWidgets('the choice can be cleared without reopening the sheet', (
      WidgetTester tester,
    ) async {
      // Removing a choice should not be harder than making one.
      await pumpForm(tester);
      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Electricity'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear category'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a category'), findsOneWidget);
    });

    testWidgets('it does not open when there are no categories to show', (
      WidgetTester tester,
    ) async {
      // A picker that opens onto an empty sheet is worse than one that waits.
      await pumpForm(tester, available: <Category>[]);

      await tester.tap(find.text('Choose a category'));
      await tester.pumpAndSettle();

      expect(find.text('Electricity'), findsNothing);
    });
  });

  group('repeating', () {
    /// Turns the Repeats field on with its default rule.
    Future<void> setRepeat(WidgetTester tester) async {
      await tester.tap(find.text('Does not repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('the form offers it, off by default', (
      WidgetTester tester,
    ) async {
      // Null is the common answer — most bills do not repeat — so it is the
      // starting state rather than something to be turned off.
      await pumpForm(tester);

      expect(find.text('Does not repeat'), findsOneWidget);
    });

    testWidgets('saving writes a template instead of a bill', (
      WidgetTester tester,
    ) async {
      // Writing a bill as well would be a duplicate the generator then tries to
      // create again, and only the unique index would stop it.
      await pumpForm(tester);
      await fillRequired(tester);
      await setRepeat(tester);
      await save(tester);

      expect(recurring.created, isNotNull);
      expect(recurring.created!.name, 'Meralco electricity');
      expect(repository.created, isNull);
    });

    testWidgets('and asks for its occurrences straight away', (
      WidgetTester tester,
    ) async {
      // So the first bill appears now rather than after tonight's scheduled run.
      await pumpForm(tester);
      await fillRequired(tester);
      await setRepeat(tester);
      await save(tester);

      expect(recurring.generateCalls, 1);
    });

    testWidgets('the screen still leaves on success', (
      WidgetTester tester,
    ) async {
      // The recurring path has no saved `Bill` to report, which is why the write
      // state carries a name. Without that the screen would sit there looking
      // like the save had failed.
      await pumpForm(tester);
      await fillRequired(tester);
      await setRepeat(tester);
      await save(tester);

      expect(find.text('bills stub'), findsOneWidget);
      expect(find.text('Meralco electricity saved'), findsOneWidget);
    });

    testWidgets('a plain bill is unaffected', (WidgetTester tester) async {
      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      expect(repository.created, isNotNull);
      expect(recurring.created, isNull);
      expect(recurring.generateCalls, 0);
    });
  });

  group('when the save fails', () {
    testWidgets('the message is shown and the form is kept', (
      WidgetTester tester,
    ) async {
      // The user has to see what they typed in order to fix it, so a rejection
      // is inline rather than a replacement screen.
      repository.failure = const NetworkException();

      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      expect(find.textContaining('No internet connection'), findsOneWidget);
      // Still on the form, with what was typed intact. The amount rather than
      // the name: the name field's hint is the same string the test types, so
      // matching on it would find the hint too.
      expect(find.text('1250.50'), findsOneWidget);
    });

    testWidgets('and it can be retried without retyping', (
      WidgetTester tester,
    ) async {
      repository.failure = const NetworkException();

      await pumpForm(tester);
      await fillRequired(tester);
      await save(tester);

      repository.failure = null;
      await save(tester);

      expect(repository.createCalls, 2);
      expect(repository.created!.name, 'Meralco electricity');
    });
  });

  group('layout', () {
    testWidgets('does not overflow at 2x text on a small phone', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(320 * 3, 568 * 3)
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
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const AddBillScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
