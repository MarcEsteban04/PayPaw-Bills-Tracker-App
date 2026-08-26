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
    Size size = const Size(392, 1200),
  }) async {
    repository = FakeBillRepository(bills: bills);

    // Tall by default so a finder does not have to scroll to reach a row. The
    // overflow test below uses a real phone instead, which is the only way this
    // suite would ever have caught the grid and the day list not fitting
    // together.
    tester.view
      ..physicalSize = size * 3
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
  ///
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

      expect(square('Friday, September 18, 2 bills, upcoming'), findsOneWidget);
      expect(square('Sunday, September 20, 1 bill, upcoming'), findsOneWidget);
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

      expect(square('Friday, September 18, 1 bill, settled'), findsOneWidget);
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
      expect(find.text('TOTAL'), findsOneWidget);
      // The month total, which no single row can show.
      expect(find.text('₱5,500.50'), findsOneWidget);
      expect(find.text('₱5,500.50 still to pay'), findsOneWidget);
    });

    testWidgets('leaves out what falls in the months either side', (
      WidgetTester tester,
    ) async {
      // The grid shows those days, and counting them would make the total
      // disagree with the heading above it.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          // Part-paid so the summary total and the row's outstanding figure
          // are different numbers, and the assertion below cannot pass by
          // finding the row.
          bill(
            id: 'a',
            dueOn: DateTime(2026, 9, 18),
            amount: 400000,
            paid: 50000,
            status: BillStatus.partiallyPaid,
          ),
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
      // The total still shows: it is what the month cost, and that does not
      // become zero because it was paid.
      expect(find.text('₱1,500.00'), findsOneWidget);
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

  group('the list under the grid', () {
    testWidgets('opens on the whole month, not on nothing', (
      WidgetTester tester,
    ) async {
      // An empty box waiting to be filled would waste the bottom half of the
      // screen and fail to say that tapping does anything.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', name: 'Converge', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      expect(find.text('Due in September'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
      expect(find.text('Converge'), findsOneWidget);
    });

    testWidgets('and dates each group when there is more than one', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', name: 'Converge', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      expect(find.text('Fri, Sep 18'), findsOneWidget);
      expect(find.text('Sun, Sep 20'), findsOneWidget);
    });

    testWidgets('tapping a date narrows it to that day', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', name: 'Converge', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();

      expect(find.text('Due Friday, September 18'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
      expect(find.text('Converge'), findsNothing);
    });

    testWidgets('a day with nothing on it says so rather than going blank', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(square('Saturday, September 19'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing is due on this day.'), findsOneWidget);
    });

    testWidgets('tapping the same date again goes back to the month', (
      WidgetTester tester,
    ) async {
      // The only obvious way back once a day is chosen.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', name: 'Converge', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();
      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();

      expect(find.text('Due in September'), findsOneWidget);
      expect(find.text('Converge'), findsOneWidget);
    });

    testWidgets('the picked day is marked as picked', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('selected')), findsOneWidget);
    });

    testWidgets('tapping a dimmed date brings its month into view', (
      WidgetTester tester,
    ) async {
      // Otherwise the panel names a day that nothing on screen points at.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 8, 30))],
      );

      await tester.tap(square('Sunday, August 30'));
      await tester.pumpAndSettle();

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('Due Sunday, August 30'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
    });

    testWidgets('changing month lets the day go', (WidgetTester tester) async {
      // A day picked in September is not a day in October, and holding it would
      // leave the panel showing one date while the grid showed thirty others.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(find.text('Due in October'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('selected')), findsNothing);
    });

    testWidgets('and Today picks today, not just its month', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 9, 3))],
      );

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Due Thursday, September 3'), findsOneWidget);
      expect(find.text('Meralco'), findsOneWidget);
    });

    testWidgets('tapping a bill opens its drawer', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(id: 'a', dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(find.text('Meralco'));
      await tester.pumpAndSettle();

      // The bills list's own drawer, so a bill reads the same wherever it is
      // opened from and the actions inside it all work.
      expect(find.text('OUTSTANDING'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
    });
  });

  testWidgets('the whole screen fits on a real phone, and scrolls', (
    WidgetTester tester,
  ) async {
    // It did not. A fixed column held the grid, the summary and the day list,
    // and on a 800dp screen the last of those hung 146 pixels off the bottom —
    // invisible to every other test here, which pumps a view tall enough to
    // hide the problem.
    await pumpCalendar(
      tester,
      size: const Size(392, 800),
      bills: <BillWithStatus>[
        bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
        bill(id: 'b', name: 'Converge', dueOn: DateTime(2026, 9, 20)),
      ],
    );

    expect(tester.takeException(), isNull);

    // And the rows below the fold are reachable rather than clipped away.
    await tester.scrollUntilVisible(find.text('Converge'), 200);
    expect(find.text('Converge'), findsOneWidget);
  });

  group('what a square says about state', () {
    testWidgets('names the status, so colour is never the only carrier', (
      WidgetTester tester,
    ) async {
      // A square that meant "overdue" by being red alone would mean nothing to
      // anyone who cannot see the difference, and red-green is the most common
      // way not to.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9), status: BillStatus.overdue),
        ],
      );

      expect(square('Tuesday, September 1, 1 bill, overdue'), findsOneWidget);
    });

    testWidgets('takes the loudest when a day holds several', (
      WidgetTester tester,
    ) async {
      // A day carrying one overdue bill and two settled ones is an overdue day.
      // A fourth colour meaning "mixed" would say nothing anybody could act on.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(
            id: 'a',
            dueOn: DateTime(2026, 9),
            status: BillStatus.paid,
            paid: 150000,
          ),
          bill(id: 'b', dueOn: DateTime(2026, 9), status: BillStatus.overdue),
          bill(
            id: 'c',
            dueOn: DateTime(2026, 9),
            status: BillStatus.paid,
            paid: 150000,
          ),
        ],
      );

      expect(square('Tuesday, September 1, 3 bills, overdue'), findsOneWidget);
    });

    testWidgets('and a settled day says settled', (WidgetTester tester) async {
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

      expect(square('Friday, September 18, 1 bill, settled'), findsOneWidget);
    });

    testWidgets('a part-paid bill is not hidden behind its date', (
      WidgetTester tester,
    ) async {
      // The one state a date cannot express: a bill can be half settled and not
      // due for weeks.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(
            dueOn: DateTime(2026, 9, 18),
            status: BillStatus.partiallyPaid,
            paid: 50000,
          ),
        ],
      );

      expect(
        square('Friday, September 18, 1 bill, partly paid'),
        findsOneWidget,
      );
    });
  });

  group('the month breakdown', () {
    testWidgets('counts each state that is actually present', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9), status: BillStatus.overdue),
          bill(id: 'b', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'c', dueOn: DateTime(2026, 9, 20)),
        ],
      );

      expect(find.text('1 overdue'), findsOneWidget);
      expect(find.text('2 upcoming'), findsOneWidget);
    });

    testWidgets('and leaves out the ones that are not', (
      WidgetTester tester,
    ) async {
      // A month with nothing overdue should not carry a chip reading "0
      // overdue"; that is a reassurance the absence already gives.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      expect(find.text('1 upcoming'), findsOneWidget);
      expect(find.textContaining('overdue'), findsNothing);
      expect(find.textContaining('settled'), findsNothing);
    });

    testWidgets('counts only the month on screen', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[
          bill(id: 'a', dueOn: DateTime(2026, 9, 18)),
          bill(id: 'b', dueOn: DateTime(2026, 8, 30), status: BillStatus.paid),
        ],
      );

      expect(find.text('1 upcoming'), findsOneWidget);
      expect(find.text('1 settled'), findsNothing);
    });
  });

  group('swiping the grid', () {
    /// A fling across the grid. Negative goes left, which is forward.
    Future<void> fling(WidgetTester tester, double dx) async {
      await tester.fling(find.bySemanticsLabel('Sunday'), Offset(dx, 0), 600);
      await tester.pumpAndSettle();
    }

    testWidgets('left goes forward a month', (WidgetTester tester) async {
      // The gesture every calendar has. Stepping through a year on a 40dp arrow
      // is a chore, and nobody tries it twice.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await fling(tester, -300);

      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('and right goes back', (WidgetTester tester) async {
      // Dragging right reveals what is to the left, which is the earlier month —
      // the direction a page turns, not the direction of travel.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await fling(tester, 300);

      expect(find.text('August 2026'), findsOneWidget);
    });

    testWidgets('a drift is not a swipe', (WidgetTester tester) async {
      // The grid sits inside a vertically scrolling list, so a thumb travelling
      // mostly downward can wander a long way sideways. Changing the month
      // underneath somebody who was reading would be worse than not having the
      // gesture at all.
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await tester.timedDrag(
        find.bySemanticsLabel('Sunday'),
        const Offset(-120, 0),
        const Duration(milliseconds: 1200),
      );
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('and it lets the day go, like the arrows do', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        bills: <BillWithStatus>[bill(dueOn: DateTime(2026, 9, 18))],
      );

      await tester.tap(square('Friday, September 18'));
      await tester.pumpAndSettle();
      await fling(tester, -300);

      expect(find.text('Due in October'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('selected')), findsNothing);
    });
  });
}
