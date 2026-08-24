import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'recurrence.dart';
import 'recurring_bill.dart';

/// A recurring bill about to be created.
///
/// Separate from [RecurringBill] for the same reason `NewBill` is separate from
/// `Bill`: the database owns `id`, `created_at` and `updated_at`, so a draft that
/// carried them would have to invent all three, and an invented timestamp is a lie
/// some later code believes.
///
/// **No owner.** `user_id` comes from the session inside the repository, so no call
/// site can pass the wrong one and none can pass somebody else's.
@immutable
class NewRecurringBill {
  const NewRecurringBill({
    required this.name,
    required this.amount,
    required this.recurrence,
    this.kind = RecurringBillKind.bill,
    this.categoryId,
    this.payee,
    this.isActive = true,
    this.alreadyCoveredThrough,
  });

  final String name;
  final Money amount;
  final Recurrence recurrence;
  final RecurringBillKind kind;
  final String? categoryId;
  final String? payee;
  final bool isActive;

  /// A date whose occurrence already exists as a bill.
  ///
  /// Set when an *existing* bill is being turned into a schedule: that bill is
  /// the occurrence for its own due date, so generation has to start after it.
  ///
  /// The unique index would catch the duplicate anyway, but only once the bill is
  /// linked to the template — and between creating the template and linking it,
  /// the scheduled job can run. This closes that window rather than relying on
  /// losing the race.
  final DateTime? alreadyCoveredThrough;

  /// The bookmark to store, derived rather than accepted.
  ///
  /// `next_due_on` is `not null` with no default, so something has to supply it on
  /// insert. Taking it as a *parameter* would let a caller store a template whose
  /// bookmark the rule can never reach, which generation would either skip forever
  /// or satisfy with a date the user never asked for. [alreadyCoveredThrough] says
  /// where to start instead of what to store, so the value always comes from the
  /// rule.
  ///
  /// Null when the rule produces nothing at all, which [validate] rejects first.
  DateTime? get nextDueOn => alreadyCoveredThrough == null
      ? recurrence.firstOccurrence
      : recurrence.occurrenceAfter(alreadyCoveredThrough!);

  /// Why this cannot be stored, or null when it can.
  ///
  /// Delegates the schedule to [Recurrence.validate] and adds the fields that are
  /// this draft's own. Mirrors the check constraints in
  /// `0005_recurring_bills.sql`, so a form can say what is wrong before the round
  /// trip rather than surfacing a Postgres error.
  String? validate() {
    final String trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      return 'Give it a name of 120 characters or fewer.';
    }
    if (payee case final String value when value.trim().length > 120) {
      return 'The payee is too long.';
    }
    // `amount_minor >= 0`, unlike a payment, which must be positive. A recurring
    // bill of zero is a placeholder for something whose amount varies, and that is
    // a real thing people track.
    if (amount.minorUnits < 0) {
      return 'The amount cannot be negative.';
    }

    if (recurrence.validate() case final String problem) {
      return problem;
    }
    if (nextDueOn == null) {
      return 'This schedule never comes due. Check the start and end dates.';
    }

    return null;
  }

  bool get isValid => validate() == null;
}
