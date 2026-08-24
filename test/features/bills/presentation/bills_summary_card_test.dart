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
      // Set whenever the status says archived, because the view derives one from
      // the other — `archived_at is not null` is the *first* branch of its case
      // expression. A row with one and not the other is not a shape the database
      // can produce, and a test built that way would be asserting against
      // something that cannot happen.
      archivedAt: status == BillStatus.archived ? DateTime(2026, 8, 12) : null,
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
      expect(find.text('2 bills'), findsOneWidget);
    });

    testWidgets('a settled bill counts for nothing', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.upcoming, outstanding: 100000),
        item(id: 'b2', status: BillStatus.paid, outstanding: 0),
      ]);

      expect(find.text('₱1,000.00'), findsOneWidget);
      expect(find.text('1 bill'), findsOneWidget);
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

    testWidgets('a figure with nothing in it is not coloured like an alarm', (
      WidgetTester tester,
    ) async {
      // A red ₱0.00 is an alarm about nothing, and it teaches the reader to
      // ignore the colour on the day it means something.
      final AppPalette palette = AppTheme.light.extension<AppPalette>()!;

      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.upcoming, outstanding: 100000),
      ]);

      expect(
        _colourOf(tester, '₱0.00'),
        isNot(palette.overdue),
        reason: 'nothing is overdue, so the figure should be muted',
      );
    });

    testWidgets('and is coloured the moment there is something to report', (
      WidgetTester tester,
    ) async {
      // The other half of the pair: without it, a card that never colours
      // anything would pass the test above.
      final AppPalette palette = AppTheme.light.extension<AppPalette>()!;

      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.overdue, outstanding: 100000),
      ]);

      // The overdue figure and the headline both read ₱1,000.00; the figure is
      // the one inside the tinted sub-panel, so it is found by colour.
      expect(_colours(tester, '₱1,000.00'), contains(palette.overdue));
    });
  });

  group('progress', () {
    testWidgets('shows what has been settled against what was billed', (
      WidgetTester tester,
    ) async {
      // A number with no denominator cannot be read as good or bad. ₱1,000
      // outstanding means one thing when nothing has been paid and another when
      // it is the last tenth of the month.
      await pumpCard(tester, <BillWithStatus>[
        // ₱5,000 billed, ₱4,000 paid.
        item(status: BillStatus.partiallyPaid, outstanding: 100000),
      ]);

      expect(find.text('₱4,000.00 of ₱5,000.00 settled'), findsOneWidget);
    });

    testWidgets('counts a settled bill as progress', (
      WidgetTester tester,
    ) async {
      // Unlike every other figure on the card, which ignores paid bills.
      // Clearing one *is* the progress.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.paid, outstanding: 0),
      ]);

      expect(find.text('₱5,000.00 of ₱5,000.00 settled'), findsOneWidget);
    });

    testWidgets('leaves an archived bill out of the denominator', (
      WidgetTester tester,
    ) async {
      // Counting it would make the total include work nobody intends to do.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.archived, outstanding: 500000),
      ]);

      expect(find.textContaining('settled'), findsNothing);
      expect(find.text('Nothing outstanding'), findsOneWidget);
    });

    testWidgets('is announced for a screen reader', (
      WidgetTester tester,
    ) async {
      // A bar is invisible without sight, and the sentence beneath it is the only
      // other place the figure appears.
      await pumpCard(tester, <BillWithStatus>[
        item(status: BillStatus.partiallyPaid, outstanding: 250000),
      ]);

      expect(find.bySemanticsLabel('Settled'), findsOneWidget);
    });
  });
}

/// The colour of the first `Text` with this content.
Color? _colourOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text).first).style?.color;

/// Every colour used by `Text` widgets with this content.
Set<Color?> _colours(WidgetTester tester, String text) => tester
    .widgetList<Text>(find.text(text))
    .map((Text widget) => widget.style?.color)
    .toSet();
