import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'debt_direction.dart';

/// A debt about to be created.
///
/// Separate from `Debt` for the reason `NewBill` is separate from `Bill`: the
/// database owns `id`, `created_at` and `updated_at`, so a draft that carried
/// them would have to invent all three, and an invented timestamp is a lie some
/// later code believes.
///
/// **No owner.** `user_id` comes from the session inside the repository, so no
/// call site can pass the wrong one and none can pass somebody else's.
///
/// **Not settled.** A debt is not created already repaid. The column defaults to
/// null and offering it here would be offering a state nothing needs.
@immutable
class NewDebt {
  const NewDebt({
    required this.direction,
    required this.counterpartyName,
    required this.principal,
    required this.incurredOn,
    this.counterpartyContact,
    this.dueOn,
    this.notes,
  });

  final DebtDirection direction;
  final String counterpartyName;
  final String? counterpartyContact;
  final Money principal;
  final DateTime incurredOn;
  final DateTime? dueOn;
  final String? notes;

  /// The longest a name or a contact may be, matching the column checks.
  static const int maxNameLength = 120;
  static const int maxContactLength = 120;
  static const int maxNotesLength = 2000;

  /// Why this cannot be stored, or null when it can.
  ///
  /// Mirrors the check constraints in `0008_debts.sql`, so a form can say what
  /// is wrong before the round trip rather than surfacing a Postgres error.
  String? validate() {
    final String name = counterpartyName.trim();

    if (name.isEmpty || name.length > maxNameLength) {
      return 'Say who this is with, in $maxNameLength characters or fewer.';
    }

    if (counterpartyContact case final String contact
        when contact.trim().length > maxContactLength) {
      return 'That contact detail is too long.';
    }

    // `principal_minor > 0`, unlike a bill's amount, which the column allows to
    // be zero so a placeholder for a varying charge can exist. A debt of nothing
    // is not a debt — there is no version of it anybody would record.
    if (principal.minorUnits <= 0) {
      return 'Enter how much the debt is for.';
    }

    // The column's own check. Money cannot be repayable before it changed
    // hands, and a date the wrong way round is a typo rather than an intention.
    if (dueOn case final DateTime due
        when due.isBefore(_dateOnly(incurredOn))) {
      return 'The repayment date cannot be before the money changed hands.';
    }

    if (notes case final String value when value.length > maxNotesLength) {
      return 'Notes are limited to $maxNotesLength characters.';
    }

    return null;
  }

  bool get isValid => validate() == null;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
