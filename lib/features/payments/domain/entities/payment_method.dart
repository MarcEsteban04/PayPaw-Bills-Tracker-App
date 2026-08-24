/// How a payment was made.
///
/// **Free text in the database, an enum here.** `payments.method` is a lowercase
/// `text` column with a documented vocabulary rather than a Postgres enum, because
/// payment methods in the Philippines are a moving target and an enum change is a
/// migration. See `supabase/migrations/0009_payments.sql`.
///
/// That choice is right for the schema and wrong for the UI, which needs a label
/// and an icon per method. This closes the gap in one place: the vocabulary the
/// column documents, spelled out where a widget can switch over it.
///
/// A method the app has not been taught parses to null and renders as the row's
/// reference or nothing at all — never as a crash, and never as the wrong method,
/// which is worse than none.
enum PaymentMethod {
  gcash('gcash', 'GCash'),
  maya('maya', 'Maya'),
  bankTransfer('bank_transfer', 'Bank transfer'),
  card('card', 'Card'),
  cash('cash', 'Cash'),
  autoDebit('auto_debit', 'Auto-debit'),
  other('other', 'Other');

  const PaymentMethod(this.wireValue, this.label);

  /// The exact lowercase string the column holds.
  final String wireValue;

  /// What the user reads.
  final String label;

  /// Parses a value from the column, or null for anything unrecognised.
  static PaymentMethod? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final PaymentMethod method in values) {
      if (method.wireValue == value) {
        return method;
      }
    }

    return null;
  }
}
