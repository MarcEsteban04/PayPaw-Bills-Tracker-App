import '../entities/reminder_preferences.dart';

/// Reads the user's reminder rules.
///
/// ## Read-only, and that is the whole contract for now
///
/// Onboarding already writes this row — see `AccountSetupRepository` — and
/// Sprint 42's settings screen will write it again. What was missing was anyone
/// reading it back: the preferences were collected, stored, and then never
/// consulted by anything.
///
/// Ownership is never a parameter. The RLS policy restricts every row to
/// `user_id = auth.uid()`, so there is exactly one row this can return.
abstract interface class ReminderPreferencesRepository {
  /// The signed-in user's rules, or the defaults.
  ///
  /// **A missing row is not an error.** Nothing seeds this table at sign-up, so
  /// absence is the common case and means "the column defaults" — which is what
  /// [ReminderPreferences]'s own defaults are. Returning null and making every
  /// caller decide would be three places inventing the same fallback.
  Future<ReminderPreferences> fetch();
}
