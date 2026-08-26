import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/widgets/bill_list_tile.dart';
import 'package:paypaw/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:paypaw/features/recurring/presentation/controllers/recurring_bill_providers.dart';

import '../../bills/helpers/fake_bill_repository.dart';

/// What the calendar costs when somebody actually uses it for a while.
///
/// The month view was built against an account with two bills. These tests pump
/// it against two hundred in one month and two thousand across four years, which
/// is what a few years of a household's utilities, subscriptions and rent looks
/// like — and they assert the thing that stops scaling first: **how much of the
/// list under the grid is built at once.**
///
/// A screen that builds every row it could ever show is not slow at two bills
/// and is unusable at two hundred, and nothing in a normal test run would say
/// so.
void main() {
  final DateTime today = DateTime(2026, 9, 3);

  BillWithStatus bill({
    required String id,
    required DateTime dueOn,
    BillStatus? status = BillStatus.upcoming,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: 'Bill $id',
      amount: const Money.php(150000),
      dueOn: dueOn,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: const Money.php(0),
    outstanding: const Money.php(150000),
    today: today,
  );

  /// [count] bills spread over [days] consecutive days from [start].
  List<BillWithStatus> spread({
    required DateTime start,
    required int days,
    required int count,
  }) => <BillWithStatus>[
    for (int i = 0; i < count; i++)
      bill(
        id: 'bill-$i',
        dueOn: DateTime(start.year, start.month, start.day + (i % days)),
      ),
  ];

  Future<void> pumpCalendar(
    WidgetTester tester,
    List<BillWithStatus> bills,
  ) async {
    // A real phone, not the tall view the other calendar tests use. How much is
    // built depends on how much fits, so a 1200dp window would hide the answer.
    tester.view
      ..physicalSize = const Size(392 * 3, 800 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          billRepositoryProvider.overrideWithValue(
            FakeBillRepository(bills: bills),
          ),
          billGenerationProvider.overrideWith((Ref ref) async => 0),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const CalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('a busy month', () {
    testWidgets('builds a screenful of rows, not the whole month', (
      WidgetTester tester,
    ) async {
      // Two hundred bills in September. Only a handful can be on screen at once
      // under a six-row grid and a summary card, and building the rest is work
      // nobody asked for on every rebuild of the screen.
      await pumpCalendar(
        tester,
        spread(start: DateTime(2026, 9), days: 30, count: 200),
      );

      // One, at the time of writing: the grid and the summary fill the first
      // screen, so the list starts just below the fold. It was two hundred.
      expect(
        tester.widgetList(find.byType(BillListTile)).length,
        lessThan(20),
        reason: 'the list under the grid should be lazy',
      );
    });

    testWidgets('and still says how many there are', (
      WidgetTester tester,
    ) async {
      // Laziness must not cost the totals. The summary counts the month, not
      // what happens to be laid out.
      await pumpCalendar(
        tester,
        spread(start: DateTime(2026, 9), days: 30, count: 200),
      );

      expect(find.text('200 bills this month'), findsOneWidget);
    });

    testWidgets('the grid still marks the days', (WidgetTester tester) async {
      await pumpCalendar(
        tester,
        spread(start: DateTime(2026, 9), days: 30, count: 200),
      );

      // 200 over 30 days is six or seven each.
      expect(
        find.bySemanticsLabel(RegExp('^Friday, September 18, [67] bills')),
        findsOneWidget,
      );
    });
  });

  group('years of history', () {
    testWidgets('opening the calendar does not build them', (
      WidgetTester tester,
    ) async {
      // Two thousand bills across four years. The month on screen is one of
      // forty-eight, and the other forty-seven should cost nothing to draw.
      await pumpCalendar(
        tester,
        spread(start: DateTime(2023), days: 1400, count: 2000),
      );

      expect(tester.takeException(), isNull);
      expect(tester.widgetList(find.byType(BillListTile)).length, lessThan(20));
    });

    testWidgets('and stepping a month stays that cheap', (
      WidgetTester tester,
    ) async {
      await pumpCalendar(
        tester,
        spread(start: DateTime(2023), days: 1400, count: 2000),
      );

      await tester.tap(find.bySemanticsLabel('Next month'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.widgetList(find.byType(BillListTile)).length, lessThan(20));
    });
  });
}
