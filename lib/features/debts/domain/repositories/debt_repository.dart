import '../entities/debt.dart';
import '../entities/debt_direction.dart';
import '../entities/debt_with_status.dart';
import '../entities/new_debt.dart';

/// Reads and writes utang.
///
/// ## Ownership is never a parameter
///
/// No method takes a `userId`. RLS restricts every statement to the signed-in
/// user, and the writes take it from the session — so no call site can pass
/// somebody else's, and none can forget.
///
/// ## Settling is not deleting
///
/// A repaid debt keeps its row. `payments.debt_id` is `on delete restrict`
/// precisely so it cannot be erased out from under the repayments recorded
/// against it, and the history of having borrowed and paid back is worth more
/// than the row costs. [deleteDebt] exists for a debt entered by mistake, and
/// the database will refuse it once anything has been paid.
abstract interface class DebtRepository {
  /// Every debt the signed-in user has.
  ///
  /// Soonest agreed date first, because "what is next" is the question a list of
  /// obligations exists to answer. Debts with **no agreed date sort last**
  /// rather than first: they are the ones nobody promised anything about, and
  /// putting a nulls-first ordering at the top of the screen would bury every
  /// debt that does have a deadline underneath them.
  ///
  /// [direction] narrows to one side of the ledger; null returns both.
  /// [includeSettled] is false by default — a list of what is owed should not
  /// open on years of things that are not.
  ///
  /// Comes back from the debt_status view, so every row already carries what
  /// has been repaid and what is left. Fetching the debts and their payments
  /// separately would be two round trips, two loading states, and a join the
  /// database is better at.
  Future<List<DebtWithStatus>> fetchDebts({
    DebtDirection? direction,
    bool includeSettled = false,
  });

  /// One debt, or null when there is no such thing visible to this user.
  ///
  /// Null rather than an exception for a missing row: through RLS "deleted" and
  /// "belongs to someone else" are the same answer and have to stay that way.
  Future<DebtWithStatus?> fetchDebt(String id);

  /// Creates one and returns the stored row.
  Future<Debt> createDebt(NewDebt draft);

  /// Saves a change to an existing one.
  Future<Debt> updateDebt(Debt debt);

  /// Marks it repaid.
  ///
  /// Separate from [updateDebt] so a screen settling a debt does not have to
  /// send every other column back with it — and so the timestamp is stamped in
  /// one place rather than at each call site.
  Future<Debt> settleDebt(String id);

  /// Marks it open again, for a settlement recorded by mistake.
  Future<Debt> reopenDebt(String id);

  /// Removes it entirely.
  ///
  /// For something entered in error. The database refuses this once a payment
  /// references the debt, which is the intended behaviour rather than a
  /// limitation: at that point the record is history and [settleDebt] is the
  /// operation being reached for.
  Future<void> deleteDebt(String id);
}
