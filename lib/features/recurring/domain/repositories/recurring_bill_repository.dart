import '../entities/new_recurring_bill.dart';
import '../entities/recurring_bill.dart';

/// Reads and writes recurring templates, and asks the server to generate from
/// them.
///
/// ## Generation is not this repository's job
///
/// [generateDueBills] triggers work that happens in the database — see
/// `supabase/migrations/0016_generate_recurring_bills.sql`. It is here because it
/// is a call the app makes, not because the app decides what gets created.
///
/// The scheduled run is the mechanism; this is a safety net and a courtesy. A
/// template created a moment ago should produce its bills now rather than after
/// tonight's job, and an installation whose `pg_cron` was never enabled should
/// still work when someone opens the app.
///
/// ## Ownership is never a parameter
///
/// No method takes a `userId`. Every method throws an `AppException` and nothing
/// else.
abstract interface class RecurringBillRepository {
  /// Every template the signed-in user has, soonest next-due first.
  Future<List<RecurringBill>> fetchRecurringBills({
    bool includeInactive = true,
  });

  /// One template, or null when there is no such template visible to this user.
  ///
  /// Null rather than an exception for a missing row: through RLS "deleted" and
  /// "belongs to someone else" are the same answer and have to stay that way.
  Future<RecurringBill?> fetchRecurringBill(String id);

  /// Stores a new template and returns it as saved.
  Future<RecurringBill> createRecurringBill(NewRecurringBill draft);

  /// Saves changes to an existing template.
  ///
  /// The whole entity, including `next_due_on`. Sprint 32 decides what editing a
  /// rule does to a bookmark that no longer matches it.
  Future<RecurringBill> updateRecurringBill(RecurringBill bill);

  /// Destroys a template.
  ///
  /// The bills it already generated survive: `bills.recurring_bill_id` is
  /// `on delete set null`, so they become ordinary bills rather than vanishing
  /// with the schedule. Deleting a template is "stop making these", not "those
  /// months never happened".
  Future<void> deleteRecurringBill(String id);

  /// Asks the database to materialise occurrences due within the lead window.
  ///
  /// Returns how many bills were created, which lets a caller tell "nothing was
  /// due" from "it did not run". Idempotent: a unique index on
  /// `(recurring_bill_id, due_on)` means calling it twice creates nothing twice.
  Future<int> generateDueBills();
}
