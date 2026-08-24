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

  /// Due within the warning window the view defines, but not today.
  dueSoon('due_soon'),

  /// Due on the user's today. The last day it can be paid on time.
  ///
  /// Separate from [dueSoon], which covered a three-day window and said the same
  /// thing about a bill due this afternoon as about one due on Friday.
  dueToday('due_today'),

  /// Something has been paid, but not all of it, and there is no date pressure.
  ///
  /// Ranks *below* the date statuses in the view, so a half-paid bill due
  /// tomorrow reports [dueToday] rather than this. Nothing is lost by that:
  /// `BillWithStatus.isPartiallyPaid` reads the amounts, not the status, so the
  /// progress bar does not depend on this value.
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
    BillStatus.dueToday ||
    BillStatus.partiallyPaid ||
    BillStatus.overdue => true,
    BillStatus.paid || BillStatus.archived => false,
  };

  /// Whether this bill wants the user's attention now.
  bool get needsAttention => switch (this) {
    BillStatus.dueSoon || BillStatus.dueToday || BillStatus.overdue => true,
    _ => false,
  };
}
