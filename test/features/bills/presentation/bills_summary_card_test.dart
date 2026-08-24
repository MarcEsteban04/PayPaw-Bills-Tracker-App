import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_palette.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/widgets/bills_summary_card.dart';

/// The panel at the top of the bill list.
///
/// It answers one question — how much is left to pay, and how much of that is
/// already late — so the arithmetic is what these tests are about.
void main() {
  BillWithStatus item({
    required BillStatus status,
    required int outstanding,
    String id = 'bill-1',
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: 'Bill $id',
      amount: const Money.php(500000),
      dueOn: DateTime(2026, 9, 5),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(500000 - outstanding),
    outstanding: Money.php(outstanding),
    today: DateTime(2026, 9, 3),
  );

  Future<void> pumpCard(WidgetTester tester, List<BillWithStatus> bills) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 900 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: BillsSummaryCard(bills: bills)),
      ),
    );
    await tester.pump();
  }

  group('the headline', () {
    testWidgets('totals what is still owed, not what the bills cost', (
      WidgetTester tester,
    ) async {
      // The difference matters on a partly paid bill: this card is a measure of
      // work left, not of what was billed.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.upcoming, outstanding: 100000),
        item(id: 'b2', status: BillStatus.partiallyPaid, outstanding: 50000),
      ]);

      expect(find.text('₱1,500.00'), findsOneWidget);
      expect(find.text('across 2 bills'), findsOneWidget);
    });

    testWidgets('a settled bill counts for nothing', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.upcoming, outstanding: 100000),
        item(id: 'b2', status: BillStatus.paid, outstanding: 0),
      ]);

      expect(find.text('₱1,000.00'), findsOneWidget);
      expect(find.text('across 1 bill'), findsOneWidget);
    });

    testWidgets('nor does an archived one', (WidgetTester tester) async {
      // Archived is not outstanding — the user has put it away.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.archived, outstanding: 100000),
      ]);

      expect(find.text('₱0.00'), findsWidgets);
      expect(find.text('Nothing outstanding'), findsOneWidget);
    });

    testWidgets('an empty list reads as zero rather than blank', (
      WidgetTester tester,
    ) async {
      // The card is only shown with bills present, but a list of nothing but
      // paid bills reaches the same code and must not divide by anything.
      await pumpCard(tester, <BillWithStatus>[]);

      expect(find.text('Nothing outstanding'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the two figures', () {
    testWidgets('split the total by urgency', (WidgetTester tester) async {
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.overdue, outstanding: 30000),
        item(id: 'b2', status: BillStatus.dueSoon, outstanding: 20000),
        item(id: 'b3', status: BillStatus.upcoming, outstanding: 50000),
      ]);

      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('₱300.00'), findsOneWidget);
      expect(find.text('Due soon'), findsOneWidget);
      expect(find.text('₱200.00'), findsOneWidget);
      // The headline is all three, including the one in neither figure.
      expect(find.text('₱1,000.00'), findsOneWidget);
    });

    testWidgets('a partly paid overdue bill counts what is left', (
      WidgetTester tester,
    ) async {
      // ₱200 paid of ₱5,000, and late. The overdue figure is ₱4,800, not ₱5,000.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.overdue, outstanding: 480000),
      ]);

      expect(find.text('₱4,800.00'), findsWidgets);
    });

    testWidgets('a figure with nothing in it is not tinted like an alarm', (
      WidgetTester tester,
    ) async {
      // A red panel reading ₱0.00 is an alarm about nothing, and it teaches the
      // reader to ignore the colour on the day it means something.
      final AppPalette palette = AppTheme.light.extension<AppPalette>()!;

      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.upcoming, outstanding: 100000),
      ]);

      expect(
        _tintColours(tester),
        isNot(contains(palette.statusTint(AppStatusTone.overdue))),
        reason: 'nothing is overdue, so nothing should be wearing the red tint',
      );
    });

    testWidgets('and is tinted the moment there is something to report', (
      WidgetTester tester,
    ) async {
      // The other half of the pair: without this, a card that never tints would
      // pass the test above.
      final AppPalette palette = AppTheme.light.extension<AppPalette>()!;

      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.overdue, outstanding: 100000),
      ]);

      expect(
        _tintColours(tester),
        contains(palette.statusTint(AppStatusTone.overdue)),
      );
    });
  });
}

/// Every background colour the card is currently painting.
///
/// Read off the widget tree rather than compared against a golden image: the
/// question is which *palette* colour a figure is wearing, and a screenshot
/// answers that only indirectly and breaks on every unrelated pixel.
Set<Color?> _tintColours(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((DecoratedBox box) {
      final Decoration decoration = box.decoration;

      return decoration is BoxDecoration ? decoration.color : null;
    })
    .toSet();
