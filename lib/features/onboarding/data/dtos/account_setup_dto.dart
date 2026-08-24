import '../../domain/entities/account_setup.dart';

/// Maps [AccountSetup] onto the two rows it is stored in.
///
/// Column names are spelled out as constants and compared against
/// `0002_profiles.sql` and `0003_reminder_preferences.sql` by eye. A wrong name
/// here is a runtime failure, not a compile error, which is why the names are
/// somewhere a reviewer can find them all at once.
abstract final class AccountSetupDto {
  // --- public.profiles ------------------------------------------------------

  static const String profilesTable = 'profiles';
  static const String columnProfileId = 'id';
  static const String columnCurrency = 'currency';
  static const String columnTimeZone = 'time_zone';

  // --- public.reminder_preferences ------------------------------------------

  static const String reminderPreferencesTable = 'reminder_preferences';
  static const String columnUserId = 'user_id';
  static const String columnDaysBefore = 'days_before';
  static const String columnTimeOfDay = 'time_of_day';
  static const String columnIsEnabled = 'is_enabled';

  /// The `profiles` half. An update, not an upsert: the row already exists,
  /// created by the `handle_new_user` trigger when the account was made.
  ///
  /// `id` is not included. It is the primary key and the RLS policy's subject,
  /// so it is matched on rather than written, and sending it would be an update
  /// the policy has to reject rather than one it never sees.
  static Map<String, dynamic> toProfileUpdate(AccountSetup setup) =>
      <String, dynamic>{
        columnCurrency: setup.currency.toUpperCase(),
        columnTimeZone: setup.timeZone,
      };

  /// The `reminder_preferences` half. An upsert, because this row may or may not
  /// exist: nothing creates it at sign-up, and onboarding can be re-run.
  ///
  /// `user_id` *is* included here — it is the conflict target, and on an insert
  /// the row cannot be attributed without it.
  static Map<String, dynamic> toReminderUpsert(
    AccountSetup setup, {
    required String userId,
  }) => <String, dynamic>{
    columnUserId: userId,
    // Sorted descending so the stored order matches the order they fire in.
    // Postgres preserves array order, so this is a real property of the row.
    columnDaysBefore: List<int>.of(setup.reminderDaysBefore)
      ..sort((int a, int b) => b.compareTo(a)),
    columnTimeOfDay: setup.reminderTime.toWireValue(),
    columnIsEnabled: setup.remindersEnabled,
  };
}
