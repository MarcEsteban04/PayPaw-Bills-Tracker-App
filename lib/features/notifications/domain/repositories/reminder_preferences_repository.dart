import '../entities/bill_reminder_override.dart';
import '../entities/reminder_preferences.dart';

/// Reads and writes the user's reminder rules.
///
/// Both halves: the defaults in `reminder_preferences`, and the per-bill
/// departures from them in `bill_reminders`. One repository rather than two
/// because nothing ever wants one without the other — the schedule is built from
/// both, and a screen editing either has to know what the other says.
///
/// Ownership is never a parameter. The RLS policy restricts every row to
/// `user_id = auth.uid()`, so there is exactly one set of rules this can return.
abstract interface class ReminderPreferencesRepository {
  /// The signed-in user's defaults, or the column defaults.
  ///
  /// **A missing row is not an error.** Nothing seeds this table at sign-up, so
  /// absence is the common case and means "the column defaults" — which are
  /// [ReminderPreferences]'s own. Returning null and making every caller decide
  /// would be three places inventing the same fallback.
  Future<ReminderPreferences> fetch();

  /// Stores the defaults.
  Future<void> save(ReminderPreferences preferences);

  /// Every per-bill override, by bill id.
  ///
  /// A map rather than a list, because the only question ever asked of it is
  /// "does this bill have one". Bills without an override are simply absent.
  Future<Map<String, BillReminderOverride>> fetchOverrides();

  /// Stores one bill's override, or removes it.
  ///
  /// **An override that overrides nothing is deleted rather than written.** The
  /// table has a check constraint refusing such a row, and the app agrees with
  /// it: a bill that follows the defaults in every respect is a bill with no
  /// override, and storing an empty one would leave a row that means nothing and
  /// has to be reasoned about forever after.
  Future<void> saveOverride(BillReminderOverride override);
}
