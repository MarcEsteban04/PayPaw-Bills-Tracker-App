import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/bills/presentation/widgets/bill_payable.dart';
import 'package:paypaw/features/payments/domain/entities/payment_method.dart';
import 'package:paypaw/features/payments/domain/entities/payment_target.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';
import 'package:paypaw/features/payments/presentation/widgets/record_payment_sheet.dart';

import '../../bills/helpers/fake_bill_repository.dart';
import '../helpers/fake_payment_repository.dart';

/// The sheet that records a payment.
///
/// The pre-filled amount is the whole design: "I paid this bill" is one tap on
/// Save, and everything else on the sheet can be ignored. A test that only proved
/// the form submits would miss the part that matters.
void main() {
  BillWithStatus item({
    int amount = 150000,
    int paid = 0,
    BillStatus status = BillStatus.dueSoon,
  }) => BillWithStatus(
    bill: Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Meralco',
      amount: Money.php(amount),
      dueOn: DateTime(2026, 9, 5),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(amount - paid),
    today: DateTime(2026, 8, 25),
  );

  late FakePaymentRepository payments;

  Future<void> openSheet(WidgetTester tester, {BillWithStatus? bill}) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 1400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    payments = FakePaymentRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentRepositoryProvider.overrideWithValue(payments),
          billRepositoryProvider.overrideWithValue(FakeBillRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showRecordPaymentSheet(
                  context: context,
                  payable: billPayable(bill ?? item()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('what it opens with', () {
    testWidgets('the full outstanding amount, ready to save', (
      WidgetTester tester,
    ) async {
      // The common case is paying the whole thing. Pre-filling makes it one tap.
      await openSheet(tester, bill: item(paid: 50000));

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );

      expect(field.controller?.text, '1000.00');
    });

    testWidgets('and a plain number, not a formatted one', (
      WidgetTester tester,
    ) async {
      // '₱1,500.00' is what the figure above it says. In the field it has to be
      // something `Money.tryParse` reads back, or an untouched sheet saves
      // nothing at all.
      await openSheet(tester);

      final TextField field = tester.widget<TextField>(
        find.byType(TextField).first,
      );

      expect(Money.tryParse(field.controller!.text), const Money.php(150000));
    });

    testWidgets('says which bill and what is left on it', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);

      expect(find.text('Meralco'), findsOneWidget);
      expect(find.text('STILL OWED'), findsOneWidget);
      expect(find.text('₱1,500.00'), findsOneWidget);
    });

    testWidgets('and dates it today, in words', (WidgetTester tester) async {
      await openSheet(tester);

      // The word is what the reader is checking for. A date would make them
      // compare two of them to find out whether it is right.
      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('saving', () {
    testWidgets('writes the pre-filled amount with one tap', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded.single.amount, const Money.php(150000));
      expect(
        payments.recorded.single.target,
        const PaymentTarget.bill('bill-1'),
      );
    });

    testWidgets('carries the method when one was chosen', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);

      await tester.tap(find.text('GCash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded.single.method, PaymentMethod.gcash);
    });

    testWidgets('and leaves it unset when the chosen one is tapped again', (
      WidgetTester tester,
    ) async {
      // The field is optional, and a picker with no way back to "unset" makes an
      // accidental tap permanent.
      await openSheet(tester);

      await tester.tap(find.text('GCash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GCash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded.single.method, isNull);
    });

    testWidgets('closes on success', (WidgetTester tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(find.text('STILL OWED'), findsNothing);
    });

    testWidgets('and stays open, saying why, when it fails', (
      WidgetTester tester,
    ) async {
      // A sheet that closes on a failed write tells the user it worked.
      await openSheet(tester);
      payments.failure = const NetworkException();

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(find.text('STILL OWED'), findsOneWidget);
      expect(find.textContaining('No internet connection'), findsOneWidget);
    });
  });

  group('a partial payment', () {
    testWidgets('is just a smaller number, with nothing to switch on', (
      WidgetTester tester,
    ) async {
      // Partial payments need no special handling anywhere: they are payments
      // that sum to less than what is due, and the view does the summing.
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, '500');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded.single.amount, const Money.php(50000));
    });
  });

  group('overpaying', () {
    testWidgets('warns without blocking the save', (WidgetTester tester) async {
      // A surcharge, a rounded-up transfer, a bill two people both paid. The
      // column permits it; refusing would leave the user unable to record what
      // their statement says.
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, '2000');
      await tester.pumpAndSettle();

      expect(find.textContaining('more than the ₱1,500.00'), findsOneWidget);

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded.single.amount, const Money.php(200000));
    });

    testWidgets('and says nothing when the amount fits', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, '1500');
      await tester.pumpAndSettle();

      expect(find.textContaining('more than the'), findsNothing);
    });
  });

  group('what it refuses', () {
    testWidgets('nothing at all', (WidgetTester tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded, isEmpty);
      expect(find.text('STILL OWED'), findsOneWidget);
    });

    testWidgets('and zero', (WidgetTester tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record payment').last);
      await tester.pumpAndSettle();

      expect(payments.recorded, isEmpty);
    });
  });
}
