import '../entities/payment.dart';

/// Reads payments.
///
/// ## Read-only, for now
///
/// Sprint 26 needs the history on a bill's detail drawer. Recording a payment is
/// a later sprint with its own form, validation and effect on the bill's status,
/// and adding a `createPayment` here before anything calls it would be a method
/// whose contract nobody has had to think through yet.
///
/// ## Ownership is never a parameter
///
/// No method takes a `userId`. RLS restricts every row to `user_id = auth.uid()`,
/// and a repository that makes the mistake impossible beats one that reports it.
///
/// Every method throws an `AppException` and nothing else.
abstract interface class PaymentRepository {
  /// What has been paid against one bill, most recent first.
  ///
  /// Most recent first because the question a history answers is "did the last
  /// one go through", not "how did this start". The opposite of the bills list,
  /// which is sorted by what happens next.
  ///
  /// An empty list for a bill with no payments, and for a bill that does not
  /// exist or belongs to someone else. Those are the same answer through RLS and
  /// have to stay the same answer.
  Future<List<Payment>> fetchPaymentsForBill(String billId);
}
