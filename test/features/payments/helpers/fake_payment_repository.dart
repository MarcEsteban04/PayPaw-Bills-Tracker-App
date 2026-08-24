import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
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

  /// Set to make the next fetch fail.
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
}
