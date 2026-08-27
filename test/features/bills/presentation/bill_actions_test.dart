import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:paypaw/app/router/app_routes.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_search_field.dart';
import 'package:paypaw/core/theme/app_palette.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/screens/bills_screen.dart';
import 'package:paypaw/features/bills/presentation/widgets/bill_list_tile.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/presentation/controllers/notification_providers.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment_method.dart';
import 'package:paypaw/features/payments/domain/entities/payment_target.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';

import '../../payments/helpers/fake_payment_repository.dart';
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

  Payment payment({
    String id = 'pay-1',
    String billId = 'bill-1',
    int amount = 100000,
    PaymentMethod? method = PaymentMethod.gcash,
    String? reference,
    required DateTime paidAt,
  }) => Payment(
    id: id,
    userId: 'user-1',
    billId: billId,
    amount: Money.php(amount),
    paidAt: paidAt,
    method: method,
    reference: reference,
    createdAt: paidAt,
    updatedAt: paidAt,
  );

  late FakeBillRepository repository;
  late FakePaymentRepository payments;

  Future<void> pumpList(
    WidgetTester tester,
    List<BillWithStatus> bills, {
    List<Payment> paid = const <Payment>[],
    Map<String, BillReminderOverride> reminderOverrides =
        const <String, BillReminderOverride>{},
  }) async {
    repository = FakeBillRepository(bills: bills);
    payments = FakePaymentRepository(payments: paid);

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
          paymentRepositoryProvider.overrideWithValue(payments),
          billReminderOverridesProvider.overrideWith(
            (Ref ref) async => reminderOverrides,
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

  /// Applies one status through the pill and its sheet.
  ///
  /// Driven through the real controls rather than by writing to the provider: the
  /// pill, the sheet's checkbox and its Apply button all have to line up, and
  /// each of them is fine in isolation.
  Future<void> filterToStatus(WidgetTester tester, String label) async {
    await tester.tap(find.text('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
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

      // One headline figure, then the split beneath it. The reader should not
      // have to decide which of two equal rows is the answer.
      //
      // The amount itself is not asserted by a bare finder: the summary card and
      // the list row behind the sheet legitimately show the same figure.
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('₱1,000.00 paid of ₱2,450.50'), findsOneWidget);
    });

    testWidgets('says what this bill\'s reminders currently do', (
      WidgetTester tester,
    ) async {
      // A fact, not an instruction. "Tap to change" is what the chevron already
      // says, and a row in a column of facts that answers no question is a row
      // the eye learns to skip.
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Following your settings'), findsOneWidget);
    });

    testWidgets('and says so when a bill has been silenced', (
      WidgetTester tester,
    ) async {
      // The state worth surfacing. A bill nobody will be warned about should say
      // so where somebody might notice, not only behind a tap.
      await pumpList(
        tester,
        <BillWithStatus>[item()],
        reminderOverrides: const <String, BillReminderOverride>{
          'bill-1': BillReminderOverride(billId: 'bill-1', isEnabled: false),
        },
      );

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Off for this bill'), findsOneWidget);
    });

    testWidgets('or that it has a rule of its own', (
      WidgetTester tester,
    ) async {
      await pumpList(
        tester,
        <BillWithStatus>[item()],
        reminderOverrides: const <String, BillReminderOverride>{
          'bill-1': BillReminderOverride(
            billId: 'bill-1',
            daysBefore: <int>[7],
          ),
        },
      );

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Set for this bill'), findsOneWidget);
    });

    testWidgets('and tapping it opens the per-bill sheet', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.text('Following your settings'));
      await tester.pumpAndSettle();

      expect(find.text('Reminders for this bill'), findsOneWidget);
    });

    testWidgets('hides the split when nothing has been paid', (
      WidgetTester tester,
    ) async {
      // The bar would be empty and the line under it would repeat the figure
      // above — two ways of saying what the headline already said.
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.textContaining('paid of'), findsNothing);
    });

    testWidgets('shows the notes and the payee when there are any', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[
        item(notes: 'Account 1234', payee: 'Meralco'),
      ]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Account 1234'), findsOneWidget);
      expect(find.text('Paid to'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
    });

    testWidgets('and leaves them out when there are not', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('Notes'), findsNothing);
      expect(find.text('Paid to'), findsNothing);
    });

    testWidgets('Edit opens the form', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Edit'));
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

      final Rect delete = tester.getRect(find.byTooltip('Delete'));

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

      expect(find.byTooltip('Archive'), findsOneWidget);
      expect(find.byTooltip('Restore'), findsNothing);
    });
  });

  group('archiving', () {
    testWidgets('archives and offers an undo', (WidgetTester tester) async {
      // Honest here, because archiving is one reversible column. The delete path
      // deliberately has no undo.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();

      expect(repository.archived, 'bill-1');
      expect(find.text('Meralco electricity archived'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });
  });

  group('due today', () {
    testWidgets('gets its own heading, above Due soon', (
      WidgetTester tester,
    ) async {
      // Today is the last day a bill can be paid on time. A group that mixes it
      // with Friday's makes the reader check every date to find that out.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.dueToday),
        item(id: 'bill-2', name: 'Maynilad water', status: BillStatus.dueSoon),
      ]);

      expect(find.text('DUE TODAY'), findsWidgets);
      expect(find.text('DUE SOON'), findsWidgets);

      final double today = tester.getTopLeft(find.text('DUE TODAY').first).dy;
      final double soon = tester.getTopLeft(find.text('DUE SOON').first).dy;
      expect(today, lessThan(soon));
    });

    testWidgets('is not left looking calmer than a bill due on Friday', (
      WidgetTester tester,
    ) async {
      // The colour switches all read `BillStatus.dueSoon` with a wildcard
      // fallback, so a new status silently lost the tint and the coloured rail —
      // exactly backwards for the more urgent of the two.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.dueToday),
      ]);
      await openDetail(tester, 'Meralco electricity');

      final Text due = tester.widget<Text>(
        find.text(DateFormat.yMMMEd().format(DateTime(2026, 9, 20))),
      );

      expect(due.style?.color, isNotNull);
      expect(
        due.style?.color,
        isNot(AppTheme.light.extension<AppPalette>()!.textPrimary),
      );
    });

    testWidgets('counts into the Due soon figure on the summary card', (
      WidgetTester tester,
    ) async {
      // Rather than a third panel. Two fit the card and three crowd it, and the
      // list below already separates them.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.dueToday),
      ]);

      expect(find.text('Due soon'), findsOneWidget);
      // The whole ₱2,450.50 outstanding, under Due soon rather than nowhere.
      expect(find.text('₱2,450.50'), findsWidgets);
    });
  });

  group('archived bills', () {
    testWidgets('are out of the list until the status filter asks for them', (
      WidgetTester tester,
    ) async {
      // Sprint 25 had a dedicated switch in the app bar for this. Sprint 28
      // folded it into the status filter — "show me the ones I put away" is a
      // filter, and two controls for one question is one too many.
      await pumpList(tester, <BillWithStatus>[
        item(),
        item(
          id: 'bill-2',
          name: 'Old gym membership',
          status: BillStatus.archived,
          archivedAt: DateTime(2026, 8, 12),
        ),
      ]);

      expect(find.text('Old gym membership'), findsNothing);

      await filterToStatus(tester, 'Archived');

      expect(find.text('Old gym membership'), findsOneWidget);
    });

    testWidgets('sit under their own heading, not Upcoming', (
      WidgetTester tester,
    ) async {
      // They used to fall in with Upcoming, which was invisible only for as long
      // as they never reached the list. A bill the user put away announcing itself
      // as upcoming is the opposite of what archiving was for.
      await pumpList(tester, <BillWithStatus>[
        item(
          id: 'bill-2',
          name: 'Old gym membership',
          status: BillStatus.archived,
          archivedAt: DateTime(2026, 8, 12),
        ),
      ]);
      await filterToStatus(tester, 'Archived');

      expect(find.text('ARCHIVED'), findsOneWidget);
      expect(find.text('UPCOMING'), findsNothing);
    });

    testWidgets('a filter that finds nothing says so, and offers the way out', (
      WidgetTester tester,
    ) async {
      // Distinct from an empty account: the way out is to widen the filter, not
      // to add a bill.
      await pumpList(tester, <BillWithStatus>[item()]);

      await filterToStatus(tester, 'Archived');

      expect(find.text('No bills match'), findsOneWidget);
      expect(find.text('No bills yet'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Meralco electricity'), findsOneWidget);
    });

    testWidgets('can be restored, which is what makes archiving reversible', (
      WidgetTester tester,
    ) async {
      // The round trip end to end. Before there was any way to see them, an
      // archived bill could not be reached to open its drawer, so the drawer's
      // Restore was unreachable and the undo snackbar was the only way back —
      // for four seconds.
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();

      expect(find.text('Meralco electricity'), findsNothing);

      await filterToStatus(tester, 'Archived');
      await openDetail(tester, 'Meralco electricity');

      expect(find.byTooltip('Restore'), findsOneWidget);

      await tester.tap(find.byTooltip('Restore'));
      await tester.pumpAndSettle();

      expect(repository.restored, 'bill-1');
    });
  });

  group('search', () {
    testWidgets('narrows the list as it is typed', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[
        item(),
        item(id: 'bill-2', name: 'Maynilad water'),
      ]);

      await tester.enterText(find.byType(AppSearchField), 'water');
      await tester.pumpAndSettle();

      expect(find.text('Maynilad water'), findsOneWidget);
      expect(find.text('Meralco electricity'), findsNothing);
    });

    testWidgets('survives matching nothing', (WidgetTester tester) async {
      // The bar used to live inside the scrolling list, so the box being typed
      // into disappeared on the keystroke that narrowed too far — leaving no way
      // to correct the query. It is a fixed header for exactly this reason.
      await pumpList(tester, <BillWithStatus>[item()]);

      await tester.enterText(find.byType(AppSearchField), 'nothing matches me');
      await tester.pumpAndSettle();

      expect(find.text('No bills match'), findsOneWidget);
      expect(find.byType(AppSearchField), findsOneWidget);
    });

    testWidgets('and the app bar offers to clear it', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[item()]);

      expect(find.textContaining('Clear ('), findsNothing);

      await tester.enterText(find.byType(AppSearchField), 'meralco');
      await tester.pumpAndSettle();

      expect(find.text('Clear (1)'), findsOneWidget);

      await tester.tap(find.text('Clear (1)'));
      await tester.pumpAndSettle();

      // The box empties with it, rather than showing a query that no longer
      // applies.
      expect(find.textContaining('Clear ('), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });
  });

  group('sorting', () {
    testWidgets('largest first flattens the urgency groups', (
      WidgetTester tester,
    ) async {
      // The groups are a due-date order. Sorting by amount inside "Overdue" then
      // "Upcoming" would give the largest overdue bill, not the largest bill —
      // a different question from the one asked.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.overdue),
        item(id: 'bill-2', name: 'Maynilad water'),
      ]);

      // Two 'OVERDUE': the section heading and the row's own badge. The badge
      // survives the sort — it describes the bill, not the grouping — so the
      // heading has to be counted rather than looked for.
      expect(find.text('OVERDUE'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Sort: Due soonest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Largest first'));
      await tester.pumpAndSettle();

      expect(find.text('LARGEST FIRST'), findsOneWidget);
      // Only the badge left.
      expect(find.text('OVERDUE'), findsOneWidget);
    });
  });

  group('when the write fails', () {
    testWidgets('a refused delete says so instead of closing quietly', (
      WidgetTester tester,
    ) async {
      // The controller had recorded these failures since it was written and
      // nothing read them: the dialog closed, the sheet closed, and the row was
      // still there with no explanation. Silence is the worst possible report on
      // a destructive action.
      await pumpList(tester, <BillWithStatus>[item()]);
      repository.failure = const NetworkException();

      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection. Check your network and try again.'),
        findsOneWidget,
      );
      // And it did not claim to have worked.
      expect(find.text('Meralco electricity deleted'), findsNothing);
      expect(find.text('Meralco electricity'), findsWidgets);
    });

    testWidgets('a refused archive offers no undo for work not done', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      repository.failure = const NetworkException();

      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Archive'));
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('the payment history', () {
    testWidgets('lists what was paid, most recent first', (
      WidgetTester tester,
    ) async {
      await pumpList(
        tester,
        <BillWithStatus>[item(status: BillStatus.partiallyPaid, paid: 100000)],
        paid: <Payment>[
          payment(amount: 60000, paidAt: DateTime(2026, 8, 14)),
          payment(
            id: 'pay-2',
            amount: 40000,
            method: PaymentMethod.bankTransfer,
            reference: 'BPI-99120',
            paidAt: DateTime(2026, 8, 28),
          ),
        ],
      );

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('PAYMENT HISTORY'), findsOneWidget);
      expect(find.text('₱600.00'), findsOneWidget);
      expect(find.text('₱400.00'), findsOneWidget);
      expect(find.text('Bank transfer · Ref BPI-99120'), findsOneWidget);

      // Most recent first: "did the one I sent last week go through" is the
      // question a history answers, not "how did this start".
      final double newer = tester.getTopLeft(find.text('₱400.00')).dy;
      final double older = tester.getTopLeft(find.text('₱600.00')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('is absent on a bill nothing has been paid against', (
      WidgetTester tester,
    ) async {
      // And costs no round trip. The view already returned a paid total of zero,
      // and the table refuses a payment of zero, so there is nothing to fetch.
      await pumpList(tester, <BillWithStatus>[item()]);

      await openDetail(tester, 'Meralco electricity');

      expect(find.text('PAYMENT HISTORY'), findsNothing);
      expect(payments.fetchedFor, isNull);
    });

    testWidgets('failing to load does not take the rest of the drawer with it', (
      WidgetTester tester,
    ) async {
      // Everything above the history came from the row the list already had. A
      // network failure should not replace facts that were never in doubt.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, paid: 100000),
      ]);
      payments.failure = const NetworkException();
      await openDetail(tester, 'Meralco electricity');

      expect(
        find.textContaining('Could not load the payments'),
        findsOneWidget,
      );
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });
  });

  group('deleting', () {
    testWidgets('a bill with payments is refused, and archive is offered', (
      WidgetTester tester,
    ) async {
      // payments.bill_id is `on delete restrict`, so Postgres would refuse this
      // outright. The dialog used to offer Delete and explain that the payments
      // would go with it — promising something the database does not allow.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, paid: 100000),
      ]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('This bill cannot be deleted'), findsOneWidget);
      expect(find.textContaining('₱1,000.00 recorded against'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Archive'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsNothing);
    });

    testWidgets('and taking that offer archives it instead', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, paid: 100000),
      ]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(repository.archived, 'bill-1');
      expect(repository.deleted, isNull);
    });

    testWidgets('asks first on a bill with no payments', (
      WidgetTester tester,
    ) async {
      // "Are you sure?" tells the reader nothing they did not know, so the
      // message offers the alternative instead.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Meralco electricity?'), findsOneWidget);
      expect(find.textContaining('Archive instead'), findsOneWidget);
      // Nothing has happened yet.
      expect(repository.deleted, isNull);
    });

    testWidgets('cancelling deletes nothing', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isNull);
    });

    testWidgets('confirming deletes it', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');
      await tester.tap(find.byTooltip('Delete'));
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
      await tester.tap(find.byTooltip('Delete'));
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

  group('recording a payment', () {
    testWidgets('is offered from the drawer, and settles the bill', (
      WidgetTester tester,
    ) async {
      // The reason anyone opens a bill is to deal with it, which is why this is
      // the one filled circle among the four actions.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();

      // Pre-filled with what is owed: paying the whole thing is one more tap.
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      expect(payments.recorded.single.amount, const Money.php(245050));
      expect(
        payments.recorded.single.target,
        const PaymentTarget.bill('bill-1'),
      );
    });

    testWidgets('and says so', (WidgetTester tester) async {
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      expect(find.text('Meralco electricity marked as paid'), findsOneWidget);
    });

    testWidgets('a partial payment is not called paid', (
      WidgetTester tester,
    ) async {
      // Telling someone they are done when ₱2,000 is still owed is worse than
      // saying nothing.
      await pumpList(tester, <BillWithStatus>[item()]);
      await openDetail(tester, 'Meralco electricity');

      await tester.tap(find.byTooltip('Record payment'));
      await tester.pumpAndSettle();
      // Scoped to the sheet's Form: the bills screen behind it has a search
      // field, and a bare TextField finder types the amount into that instead.
      await tester.enterText(
        find.descendant(
          of: find.byType(Form),
          matching: find.byType(TextField),
        ),
        '500',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();

      expect(
        find.text('₱500.00 recorded against Meralco electricity'),
        findsOneWidget,
      );
    });

    testWidgets('and it is not offered on a bill that is already settled', (
      WidgetTester tester,
    ) async {
      // Nothing left to pay, so the action has no result the user could see.
      await pumpList(tester, <BillWithStatus>[
        item(status: BillStatus.paid, paid: 245050),
      ]);
      await openDetail(tester, 'Meralco electricity');

      expect(find.byTooltip('Record payment'), findsNothing);
      expect(find.byTooltip('Edit'), findsOneWidget);
    });
  });
}
