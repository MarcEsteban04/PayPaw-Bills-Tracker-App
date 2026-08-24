import '../../../../core/domain/money.dart';

/// Rules for a bill the user is entering.
///
/// Pure functions returning `null` when acceptable and a message otherwise —
/// Flutter's `FormFieldValidator` signature, so a `TextFormField` takes one
/// directly. Same shape as `AuthValidators`, for the same reason: one definition
/// serving the add form, the edit form and any import.
///
/// These are **stricter than the database on purpose.** The columns permit a zero
/// amount and a due date centuries away so that an import or a migration can
/// carry odd historical data; a person typing into a form should not be able to.
/// The database is the last line, not the first.
abstract final class BillValidators {
  /// Matches the `char_length(name) between 1 and 120` check on the column.
  static const int maxNameLength = 120;
  static const int maxPayeeLength = 120;
  static const int maxNotesLength = 2000;

  /// Sanity bounds on a due date. Wide enough for a bill someone forgot last year
  /// and one scheduled a decade out; narrow enough to catch a mistyped year,
  /// which is the actual failure — `2062` instead of `2026`.
  static const int maxYearsInPast = 10;
  static const int maxYearsInFuture = 25;

  static String? name(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Give this bill a name';
    }
    if (trimmed.length > maxNameLength) {
      return 'Keep the name under $maxNameLength characters';
    }

    return null;
  }

  static String? payee(String? value) {
    final String trimmed = value?.trim() ?? '';

    // Optional: plenty of bills are named after who they are paid to.
    if (trimmed.length > maxPayeeLength) {
      return 'Keep this under $maxPayeeLength characters';
    }

    return null;
  }

  static String? notes(String? value) {
    if ((value ?? '').length > maxNotesLength) {
      return 'Notes are limited to $maxNotesLength characters';
    }

    return null;
  }

  /// Validates a typed amount.
  ///
  /// Rejects zero, unlike the column. A bill for nothing is not a bill, and
  /// accepting it would put a row in the list that can never be paid or cleared.
  static String? amount(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Enter the amount';
    }

    final Money? parsed = Money.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter an amount like 1250.50';
    }
    if (parsed.minorUnits < 0) {
      return 'The amount cannot be negative';
    }
    if (parsed.isZero) {
      return 'Enter an amount greater than zero';
    }

    return null;
  }

  /// Validates a chosen due date.
  ///
  /// [today] is passed in rather than read from the clock, so this stays a pure
  /// function and a test does not have to mock time.
  static String? dueDate(DateTime? value, {required DateTime today}) {
    if (value == null) {
      return 'Choose a due date';
    }

    final DateTime earliest = DateTime(
      today.year - maxYearsInPast,
      today.month,
      today.day,
    );
    final DateTime latest = DateTime(
      today.year + maxYearsInFuture,
      today.month,
      today.day,
    );

    if (value.isBefore(earliest)) {
      return 'That date is too far in the past';
    }
    if (value.isAfter(latest)) {
      // The mistyped-year case: 2062 for 2026.
      return 'That date is too far in the future — check the year';
    }

    return null;
  }

  /// Whether every field of a bill is acceptable. Convenience for a submit
  /// button, so a form does not have to remember the list.
  static bool isComplete({
    required String? name,
    required String? amount,
    required DateTime? dueOn,
    required DateTime today,
    String? payee,
    String? notes,
  }) {
    return BillValidators.name(name) == null &&
        BillValidators.amount(amount) == null &&
        BillValidators.dueDate(dueOn, today: today) == null &&
        BillValidators.payee(payee) == null &&
        BillValidators.notes(notes) == null;
  }
}
