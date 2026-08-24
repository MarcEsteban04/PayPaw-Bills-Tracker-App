/// What state a bill is in.
///
/// **Computed by the database, never by the app.** The `bill_status` view derives
/// it from the due date and the payments recorded, and the app reads the result.
/// See `docs/database_schema.md`.
///
/// That matters here because it is tempting to add a `statusOf(bill)` helper to
/// this file. Doing so would create a second definition of "due soon" that drifts
/// from the view's the first time either changes — and the client's version would
/// be computed against the device's clock and timezone rather than the user's.
enum BillStatus {
  /// Not due yet, and outside the warning window.
  upcoming('upcoming'),

  /// Due within the warning window the view defines.
  dueSoon('due_soon'),

  /// Something has been paid, but not all of it, and it is not yet late.
  partiallyPaid('partially_paid'),

  /// Past its due date and not settled. Outranks [partiallyPaid]: money owed
  /// past the date is overdue whatever has been paid against it.
  overdue('overdue'),

  /// Settled, including overpaid.
  paid('paid'),

  /// Put away by the user. No urgency, whatever the date says.
  archived('archived');

  const BillStatus(this.wireValue);

  /// The exact string the `bill_status` view produces.
  final String wireValue;

  /// Parses a value from the view.
  ///
  /// Returns null for anything unrecognised rather than throwing or guessing. A
  /// new status added to the view should surface as "unknown" in the UI, not as a
  /// crash on a screen the user was only reading — and not as a wrong status,
  /// which is worse than none.
  static BillStatus? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final BillStatus status in values) {
      if (status.wireValue == value) {
        return status;
      }
    }

    return null;
  }

  /// Whether this bill still needs money.
  bool get isOutstanding => switch (this) {
    BillStatus.upcoming ||
    BillStatus.dueSoon ||
    BillStatus.partiallyPaid ||
    BillStatus.overdue => true,
    BillStatus.paid || BillStatus.archived => false,
  };

  /// Whether this bill wants the user's attention now.
  bool get needsAttention => switch (this) {
    BillStatus.dueSoon || BillStatus.overdue => true,
    _ => false,
  };
}
