import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/payments/domain/entities/new_payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment_target.dart';
import 'package:paypaw/features/payments/domain/repositories/payment_repository.dart';

/// An in-memory [PaymentRepository].
///
/// Returns only the payments belonging to the bill asked for, rather than
/// whatever it was handed, so a test that wires the wrong bill id sees an empty
/// history instead of somebody else's payments.
class FakePaymentRepository implements PaymentRepository {
  FakePaymentRepository({List<Payment> payments = const <Payment>[]})
    : _payments = List<Payment>.of(payments);

  final List<Payment> _payments;

  /// The bill the last fetch asked about. Lets a test assert that an unpaid
  /// bill's drawer makes no round trip at all.
  String? fetchedFor;

  /// Every draft it was asked to record, in order.
  final List<NewPayment> recorded = <NewPayment>[];

  /// Set to make the next fetch or write fail.
  AppException? failure;

  @override
  Future<List<Payment>> fetchPaymentsForBill(String billId) async {
    fetchedFor = billId;

    if (failure case final AppException exception) {
      throw exception;
    }

    return _payments.where((Payment p) => p.billId == billId).toList()
      ..sort((Payment a, Payment b) => b.paidAt.compareTo(a.paidAt));
  }

  @override
  Future<List<Payment>> fetchPaymentsForDebt(String debtId) async {
    fetchedFor = debtId;

    if (failure case final AppException exception) {
      throw exception;
    }

    return _payments.where((Payment p) => p.debtId == debtId).toList()
      ..sort((Payment a, Payment b) => b.paidAt.compareTo(a.paidAt));
  }

  @override
  Future<Payment> recordPayment(NewPayment draft) async {
    if (failure case final AppException exception) {
      throw exception;
    }

    recorded.add(draft);

    // Kept, so a test can record a payment and then read the history back and
    // find it — the real repository's insert is visible to the next select, and
    // a fake where it is not would let a broken invalidation pass.
    final Payment stored = Payment(
      id: 'payment-${recorded.length}',
      userId: 'user-1',
      billId: switch (draft.target) {
        BillTarget(:final String id) => id,
        DebtTarget() => null,
      },
      debtId: switch (draft.target) {
        DebtTarget(:final String id) => id,
        BillTarget() => null,
      },
      amount: draft.amount,
      paidAt: draft.paidAt,
      method: draft.method,
      reference: draft.reference,
      note: draft.note,
      createdAt: draft.paidAt,
      updatedAt: draft.paidAt,
    );
    _payments.add(stored);

    return stored;
  }
}
