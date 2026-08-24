import '../../../../core/domain/money.dart';

/// Rules for a payment the user is recording.
///
/// Pure functions returning `null` when acceptable and a message otherwise, the
/// same shape as `BillValidators` and for the same reason — one definition, and
/// a `TextFormField` takes it directly.
///
/// Stricter than the columns on purpose. The database is the last line.
abstract final class PaymentValidators {
  /// Matches `char_length(reference) <= 120` on the column.
  static const int maxReferenceLength = 120;

  /// Matches `char_length(note) <= 500`.
  static const int maxNoteLength = 500;

  /// How far back a payment may be dated. Wide enough for someone catching up on
  /// a year of receipts, narrow enough to catch a mistyped year.
  static const int maxYearsInPast = 10;

  static String? amount(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return 'Enter how much was paid';
    }

    final Money? parsed = Money.tryParse(trimmed);
    if (parsed == null) {
      return 'Enter an amount like 1250.50';
    }
    if (parsed.minorUnits < 0) {
      return 'The amount cannot be negative';
    }
    if (parsed.isZero) {
      // A refund is not a negative payment and a nil payment is not a payment.
      // Both would make every sum this app shows a guess.
      return 'Enter an amount greater than zero';
    }

    return null;
  }

  /// Validates when the money moved.
  ///
  /// **The future is the real rule here.** A due date can be years out; a payment
  /// cannot have happened tomorrow, and a bill marked settled by a payment dated
  /// next month is a bill that looks paid while the money is still in the
  /// account.
  ///
  /// [today] is passed in rather than read from the clock, so this stays pure and
  /// a test does not have to mock time.
  static String? paidAt(DateTime? value, {required DateTime today}) {
    if (value == null) {
      return 'Choose when it was paid';
    }

    // Compared by date, not by instant. A payment recorded at 9pm for "today"
    // carries the moment it was entered, and an instant comparison would reject
    // it a fraction of a second later.
    final DateTime day = DateTime(value.year, value.month, value.day);
    final DateTime latest = DateTime(today.year, today.month, today.day);
    final DateTime earliest = DateTime(
      today.year - maxYearsInPast,
      today.month,
      today.day,
    );

    if (day.isAfter(latest)) {
      return 'A payment cannot be dated in the future';
    }
    if (day.isBefore(earliest)) {
      return 'That date is too far in the past — check the year';
    }

    return null;
  }

  static String? reference(String? value) {
    if ((value?.trim().length ?? 0) > maxReferenceLength) {
      return 'Keep the reference under $maxReferenceLength characters';
    }

    return null;
  }

  static String? note(String? value) {
    if ((value?.trim().length ?? 0) > maxNoteLength) {
      return 'Notes are limited to $maxNoteLength characters';
    }

    return null;
  }

  /// Whether every field is acceptable. Convenience for a submit button, so a
  /// form does not have to remember the list.
  static bool isComplete({
    required String? amount,
    required DateTime? paidAt,
    required DateTime today,
    String? reference,
    String? note,
  }) =>
      PaymentValidators.amount(amount) == null &&
      PaymentValidators.paidAt(paidAt, today: today) == null &&
      PaymentValidators.reference(reference) == null &&
      PaymentValidators.note(note) == null;

  /// A warning, not an error: this much over what is still owed.
  ///
  /// Overpaying is a real thing that happens — a surcharge, a rounded-up
  /// transfer, a bill paid twice by two people in a household — and the column
  /// permits it, so refusing it here would leave a user unable to record what
  /// their bank statement actually says.
  ///
  /// But it is nearly always a typo. Returns a sentence to show *beside* the
  /// field, leaving the Save button alive.
  static String? overpaymentWarning(String? value, {required Money owed}) {
    final Money? parsed = Money.tryParse(value?.trim() ?? '');

    if (parsed == null || parsed.minorUnits <= owed.minorUnits) {
      return null;
    }

    return 'That is more than the ${owed.format()} still owed';
  }
}
