/// The unit a recurrence steps by.
///
/// Four values, not the six the roadmap lists. **Bi-weekly is [weekly] with an
/// interval of 2, and "custom" is any of these with an interval above 1** — so
/// adding wire values for them would be two more ways to say what the interval
/// already says, and two more branches in every switch that has to agree with the
/// others. The user-facing labels are a Sprint 30 concern; this is the wire.
///
/// The values match the `frequency` check constraint in
/// `supabase/migrations/0005_recurring_bills.sql` exactly. A mismatch is a runtime
/// insert failure, not a compile error.
///
/// ## Quarterly overlaps monthly, deliberately
///
/// Every quarterly rule is expressible as monthly with three times the interval.
/// It is kept because "every quarter" is a thing people say and a thing bills do,
/// and because the alternative is a UI that offers "Monthly, every 3 months".
/// The cost is that two rows can mean the same schedule, so the client picks the
/// coarsest unit that fits and never emits monthly with an interval divisible
/// by 3. See `Recurrence.canonical`.
enum RecurrenceFrequency {
  weekly('weekly'),
  monthly('monthly'),
  quarterly('quarterly'),
  yearly('yearly');

  const RecurrenceFrequency(this.wireValue);

  /// The exact string the `frequency` column holds.
  final String wireValue;

  /// How many months one step of this frequency covers, or null for [weekly].
  ///
  /// Weekly is the odd one out: it steps in days and cannot be expressed in
  /// months at all. Null rather than zero, so a caller that forgets to handle it
  /// gets a type error instead of a schedule that never advances.
  int? get monthsPerStep => switch (this) {
    RecurrenceFrequency.weekly => null,
    RecurrenceFrequency.monthly => 1,
    RecurrenceFrequency.quarterly => 3,
    RecurrenceFrequency.yearly => 12,
  };

  /// Whether a rule of this frequency needs a weekday rather than a day of month.
  bool get needsWeekday => this == RecurrenceFrequency.weekly;

  /// Whether a rule of this frequency needs a month of year.
  bool get needsMonthOfYear => this == RecurrenceFrequency.yearly;

  /// Parses a value from the column, or null for anything unrecognised.
  ///
  /// Null rather than a throw, for the same reason `BillStatus.tryParse` returns
  /// null: a value added to the constraint before the app is updated should
  /// surface as unknown on a screen someone was only reading.
  static RecurrenceFrequency? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final RecurrenceFrequency frequency in values) {
      if (frequency.wireValue == value) {
        return frequency;
      }
    }

    return null;
  }
}
