import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../../bills/helpers/fake_bill_repository.dart';

/// The month view.
///
/// What it is being asked is "is there a heavy week coming", and the tests below
/// are the ways a grid can answer that wrongly: the dates on the wrong weekdays,
/// today on the wrong square, a bill counted in the wrong month, or an archived
/// bill counted at all.
void main() {
  /// The 3rd of September 2026, which is what `today` is on every row here.
  final DateTime today = DateTime(2026, 9, 3);

  BillWithStatus bill({
    String id = 'bill-1',
    String name = 'Meralco',
    required DateTime dueOn,
    BillStatus? status = BillStatus.upcoming,
    int amount = 150000,
    int paid = 0,
    DateTime? archivedAt,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      amount: Money.php(amount),
      dueOn: dueOn,
      archivedAt: archivedAt,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(amount - paid),
    today: today,
  );

  late FakeBillRepository repository;

  Future<void> pumpCalendar(
    WidgetTester tester, {
    List<BillWithStatus> bills = const <BillWithStatus>[],
  }) async {
    repository = FakeBillRepository(bills: bills);

    tester.view
      ..physicalSize = const Size(392 * 3, 1200 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(repository),
          // Generation is a round trip the calendar has no opinion about, and
          // the real one reaches Supabase.
          billGenerationProvider.overrideWith((Ref ref) async => 0),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The square showing [day] in the month currently on screen.
  ///
  /// Found by its spoken label rather than by its number, because a grid shows
  /// the same number twice whenever a month leads or trails into another.
  Finder square(String semanticLabel) =>
      find.bySemanticsLabel(RegExp('^$semanticLabel'));

  group('the month it opens on', () {
    testWidgets('is the one today falls in', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('with today marked, and only today', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(square('Today, Thursday, September 3'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Today, ')), findsOneWidget);
    });

    testWidgets('and no way back to a month it is already on', (
      WidgetTester tester,
    ) async {
      // A permanently visible "Today" on today's own month is a control that
      // visibly does nothing, which teaches the user to stop reading the row.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(find.text('Today'), findsNothing);
    });
  });

  group('the grid', () {
    testWidgets('runs the columns from Sunday', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(find.bySemanticsLabel('Sunday'), findsOneWidget);
      expect(find.bySemanticsLabel('Saturday'), findsOneWidget);
    });

    testWidgets('shows the days either side rather than blanking them', (
      WidgetTester tester,
    ) async {
      // 1 September 2026 is a Tuesday, so the grid opens on 30 August — which is
      // exactly where a bill that has just gone overdue sits.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(square('Sunday, August 30'), findsOneWidget);
      expect(square('Saturday, October 10'), findsOneWidget);
    });
  });

  group('what a square counts', () {
    testWidgets('the bills due on it, by number', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'c', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      expect(square('Friday, September 18, 2 bills due'), findsOneWidget);
      expect(square('Sunday, September 20, 1 bill due'), findsOneWidget);
    });

    testWidgets('a day with nothing on it says so', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(square('Saturday, September 19, nothing due'), findsOneWidget);
    });

    testWidgets('and an archived bill is not counted', (
      WidgetTester tester,
    ) async {
      // It was put away. A marked square would be the calendar insisting on
      // something the user has already dismissed.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(
            dueOn: DateTime(2026, 9, 18),
            status: BillStatus.archived,
            archivedAt: DateTime(2026, 8, 20),
          ),
        ],
      );

      expect(square('Friday, September 18, nothing due'), findsOneWidget);
    });

    testWidgets('a settled bill still is', (WidgetTester tester) async {
      // "This was paid on time" is part of what a month view is for.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(
            dueOn: DateTime(2026, 9, 18),
            status: BillStatus.paid,
            paid: 150000,
          ),
        ],
      );

      expect(square('Friday, September 18, 1 bill due'), findsOneWidget);
    });
  });

  group('stepping through months', () {
    testWidgets('forward, and the Today button appears', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('back across a year boundary', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      for (int i = 0; i < 9; i++) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pumpAndSettle();
      }

      expect(find.text('December 2025'), findsOneWidget);
    });

    testWidgets('and Today brings it back in one tap', (
      WidgetTester tester,
    ) async {
      // Stepping four months out and finding no way back but four taps is the
      // standard way a calendar wastes somebody's time.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      for (int i = 0; i < 4; i++) {
        await tester.tap(find.bySemanticsLabel('Next month'));
        await tester.pumpAndSettle();
      }
      expect(find.text('January 2027'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('today is not marked in a month it is not in', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('^Today, ')), findsNothing);
    });
  });

  group('the month summary', () {
    testWidgets('counts the bills and totals what is still owed', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18), amount: 400000),
          bill(id: 'b', dueOn: DateTime(2026, 9, 20), amount: 150050),
        ],
      );

      expect(find.text('2 bills this month'), findsOneWidget);
      expect(find.text('₱5,500.50'), findsOneWidget);
    });

    testWidgets('leaves out what falls in the months either side', (
      WidgetTester tester,
    ) async {
      // The grid shows those days, and counting them would make the total
      // disagree with the heading above it.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18), amount: 400000),
          bill(id: 'b', dueOn: DateTime(2026, 8, 30), amount: 999900),
          bill(id: 'c', dueOn: DateTime(2026, 10, 10), amount: 999900),
        ],
      );

      expect(find.text('1 bill this month'), findsOneWidget);
      expect(find.text('₱4,000.00'), findsOneWidget);
    });

    testWidgets('says a settled month is settled rather than showing zero', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(
            dueOn: DateTime(2026, 9, 18),
            status: BillStatus.paid,
            paid: 150000,
          ),
        ],
      );

      expect(find.text('All settled'), findsOneWidget);
      expect(find.text('₱0.00'), findsNothing);
    });

    testWidgets('and an empty month says nothing is due', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 11, 18))],
      );

      expect(find.text('Nothing is due this month.'), findsOneWidget);
    });
  });

  testWidgets('an account with no bills still gets a calendar', (
    WidgetTester tester,
  ) async {
    // There is no row to read `today` from, so the device clock is the only
    // answer available — and there is nothing on screen for it to contradict.
    await pumpCalendar(tester);

    expect(find.text('Nothing is due this month.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Today, ')), findsOneWidget);
  });
}
