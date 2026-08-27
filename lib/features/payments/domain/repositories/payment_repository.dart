import '../entities/new_payment.dart';
import '../entities/payment.dart';

/// Reads and records payments.
///
/// ## No update, and no delete either
///
/// Sprint 37 added recording. It did not add editing: a payment is a record of
/// something that happened, and the fix for a wrong one is to remove it and enter
/// what actually occurred. Deleting is not here yet because nothing offers it —
/// when something does, it arrives with the confirmation it needs.
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

  /// What has been repaid against one debt, most recent first.
  ///
  /// The same contract as [fetchPaymentsForBill] in every respect — including
  /// that a debt which does not exist and one belonging to somebody else are
  /// both an empty list, because through RLS they are the same answer.
  ///
  /// Its own method rather than one taking a [PaymentTarget], because the two
  /// filter on different columns and a single method would have to switch on the
  /// target to build its query — which is the same switch, moved somewhere it
  /// reads as less obvious.
  Future<List<Payment>> fetchPaymentsForDebt(String debtId);

  /// Records money moving against a bill, and returns the stored row.
  ///
  /// **This does not touch the bill.** Nothing here marks it paid, because
  /// nothing stores whether it is: `bill_status` derives that by comparing the
  /// sum of payments against the amount due. A payment that settles a bill and a
  /// payment that half-settles one are the same insert, and the caller's job
  /// afterwards is to re-read, not to reason.
  ///
  /// Returns the row as the database wrote it rather than the draft, so the
  /// caller sees the real id and the real timestamps instead of what it hoped
  /// for.
  Future<Payment> recordPayment(NewPayment draft);
}
