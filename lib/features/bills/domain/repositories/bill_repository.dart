import '../entities/bill.dart';
import '../entities/bill_with_status.dart';
import '../entities/new_bill.dart';

/// Reads and writes bills.
///
/// ## Reads return [BillWithStatus], writes take and return [Bill]
///
/// That asymmetry is deliberate. Reads come from the `bill_status` view, which
/// carries the derived status and payment totals a screen needs. Writes go to the
/// `bills` table, which is the only thing there is to write — a status is not
/// something a client gets to set.
///
/// ## Ownership is never a parameter
///
/// No method takes a `userId`. The implementation reads it from the session, so a
/// caller cannot pass the wrong one and cannot pass somebody else's. RLS would
/// refuse either way, but a repository that makes the mistake impossible beats
/// one that reports it.
///
/// ## Errors
///
/// Every method throws an `AppException` and nothing else. Implementations funnel
/// their failures through `mapSupabaseError`, so nothing above this contract
/// learns which backend is in use.
abstract interface class BillRepository {
  /// Every bill the signed-in user has, soonest due first.
  ///
  /// Archived bills are excluded by default: archiving is the user saying "stop
  /// showing me this", and a list that ignores that is a list that ignores them.
  Future<List<BillWithStatus>> fetchBills({bool includeArchived = false});

  /// One bill, or null when there is no such bill *visible to this user*.
  ///
  /// Null rather than an exception for a missing row, because the two cases —
  /// "deleted" and "belongs to someone else" — are indistinguishable through RLS
  /// and must stay that way. Reporting them differently would confirm that a
  /// stranger's bill exists.
  Future<BillWithStatus?> fetchBill(String id);

  /// Stores a new bill and returns it as saved, with the id and timestamps the
  /// database assigned.
  ///
  /// Returns the stored row rather than void so the caller does not have to
  /// re-fetch to learn the id — and so a column with a database default arrives
  /// with the value the database actually chose.
  Future<Bill> createBill(NewBill draft);

  /// Saves changes to an existing bill and returns the stored result.
  ///
  /// The whole entity, not a patch. A partial update needs a way to distinguish
  /// "leave this alone" from "set this to null", and every scheme for that is
  /// worse than sending all of it — the row is a dozen small columns.
  Future<Bill> updateBill(Bill bill);

  /// Puts a bill away without destroying it.
  ///
  /// The normal way a bill leaves a list. A bill with payments recorded against it
  /// cannot be deleted without taking that history with it, and the history is
  /// the part the user cares about months later.
  Future<Bill> archiveBill(String id);

  /// Brings an archived bill back.
  Future<Bill> unarchiveBill(String id);

  /// Destroys a bill that has no payments against it.
  ///
  /// **Fails when there are payments.** `payments.bill_id` is `on delete
  /// restrict`, which is what makes "archive, do not delete" real: the record of
  /// what was actually paid cannot vanish with the bill it paid. Reminders and
  /// attachment rows do cascade — those are the app's own bookkeeping, not the
  /// user's.
  ///
  /// This doc said "cascade" until Sprint 26, and the delete dialog was written
  /// against it: it offered to delete a part-paid bill and explained that the
  /// payments would go too. Postgres would have refused. Callers should check the
  /// paid total and offer [archiveBill] instead.
  Future<void> deleteBill(String id);
}
