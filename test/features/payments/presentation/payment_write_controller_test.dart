import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_detail_provider.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_repository_provider.dart';
import 'package:paypaw/features/payments/domain/entities/new_payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment_target.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_providers.dart';
import 'package:paypaw/features/payments/presentation/controllers/payment_write_controller.dart';

import '../../bills/helpers/fake_bill_repository.dart';
import '../helpers/fake_payment_repository.dart';

/// Recording a payment, and what has to be re-read afterwards.
///
/// The invalidation is the substance here. **Nothing stores whether a bill is
/// paid** — `bill_status` derives it by summing payments — so an insert leaves
/// the app's idea of the bill stale in three places at once, and a controller
/// that forgets one of them produces a screen showing a bill still owing money
/// that has just been settled.
void main() {
  BillWithStatus bill({int outstanding = 150000}) => BillWithStatus(
    bill: Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Meralco',
      amount: const Money.php(150000),
      dueOn: DateTime(2026, 9, 5),
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: BillStatus.dueSoon,
    paid: Money.php(150000 - outstanding),
    outstanding: Money.php(outstanding),
    today: DateTime(2026, 8, 25),
  );

  NewPayment draft({int amount = 150000}) => NewPayment.forBill(
    billId: 'bill-1',
    amount: Money.php(amount),
    paidAt: DateTime(2026, 8, 25, 10),
  );

  ({
    ProviderContainer container,
    FakePaymentRepository payments,
    FakeBillRepository bills,
  })
  harness() {
    final FakePaymentRepository payments = FakePaymentRepository();
    final FakeBillRepository bills = FakeBillRepository(
      bills: <BillWithStatus>[bill()],
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        paymentRepositoryProvider.overrideWithValue(payments),
        billRepositoryProvider.overrideWithValue(bills),
      ],
    );
    addTearDown(container.dispose);

    return (container: container, payments: payments, bills: bills);
  }

  group('recording one', () {
    test('sends the draft through and reports the amount back', () async {
      final harnessResult = harness();
      final PaymentWriteController controller = harnessResult.container.read(
        paymentWriteControllerProvider.notifier,
      );

      expect(await controller.record(draft(amount: 50000)), isTrue);

      expect(
        harnessResult.payments.recorded.single.amount,
        const Money.php(50000),
      );
      expect(
        harnessResult.payments.recorded.single.target,
        const PaymentTarget.bill('bill-1'),
      );
      expect(
        harnessResult.container.read(paymentWriteControllerProvider).recorded,
        const Money.php(50000),
      );
    });

    test(
      're-reads the bills, so every figure derived from them follows',
      () async {
        final harnessResult = harness();

        // Listened to, not just read: an unwatched provider has nothing to
        // invalidate and the assertion would pass without the controller doing
        // anything.
        harnessResult.container.listen(
          billsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        await harnessResult.container.read(billsProvider.future);
        final int before = harnessResult.bills.fetchCalls;

        await harnessResult.container
            .read(paymentWriteControllerProvider.notifier)
            .record(draft());
        await harnessResult.container.read(billsProvider.future);

        expect(harnessResult.bills.fetchCalls, greaterThan(before));
      },
    );

    test('and the history of the bill it was against', () async {
      final harnessResult = harness();

      harnessResult.container.listen(
        paymentsForBillProvider('bill-1'),
        (_, _) {},
        fireImmediately: true,
      );
      await harnessResult.container.read(
        paymentsForBillProvider('bill-1').future,
      );

      await harnessResult.container
          .read(paymentWriteControllerProvider.notifier)
          .record(draft(amount: 25000));

      final List<Payment> history = await harnessResult.container.read(
        paymentsForBillProvider('bill-1').future,
      );

      // The payment that was just written is in it. A stale history is the one
      // the user is staring at while wondering whether the tap registered.
      expect(history.single.amount, const Money.php(25000));
    });
  });

  group('when it fails', () {
    test('reports a message and does not claim success', () async {
      final harnessResult = harness();
      harnessResult.payments.failure = const NetworkException();

      final PaymentWriteController controller = harnessResult.container.read(
        paymentWriteControllerProvider.notifier,
      );

      expect(await controller.record(draft()), isFalse);

      final PaymentWriteState state = harnessResult.container.read(
        paymentWriteControllerProvider,
      );
      expect(state.errorMessage, isNotNull);
      expect(state.isSaving, isFalse);
      // Never set, so the sheet does not close and the toast does not fire on a
      // payment that was refused.
      expect(state.recorded, isNull);
    });
  });

  group('the success flag is an event, not a fact', () {
    test('a second write clears the first one before it starts', () async {
      // The bug this exists for shipped once on the bill form: `recorded` set by
      // the previous save survived, so the next one went ₱500 → ₱200 rather than
      // null → something, and the screen watching for that transition never
      // fired. No message, no close, and a form that looked like it had failed
      // while the row sat saved in the database.
      final harnessResult = harness();
      final PaymentWriteController controller = harnessResult.container.read(
        paymentWriteControllerProvider.notifier,
      );

      await controller.record(draft(amount: 50000));

      Money? seenDuringSecond;
      harnessResult.container.listen(paymentWriteControllerProvider, (
        _,
        PaymentWriteState next,
      ) {
        if (next.isSaving) {
          seenDuringSecond = next.recorded;
        }
      });

      await controller.record(draft(amount: 20000));

      expect(seenDuringSecond, isNull);
      expect(
        harnessResult.container.read(paymentWriteControllerProvider).recorded,
        const Money.php(20000),
      );
    });
  });
}
