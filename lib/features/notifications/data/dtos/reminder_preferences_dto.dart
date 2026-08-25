import '../../domain/entities/reminder_preferences.dart';
import '../../domain/entities/reminder_time.dart';

/// Reads a `public.reminder_preferences` row.
///
/// Read-only. Onboarding writes this table through `AccountSetupDto`, which
/// owns the upsert; duplicating it here would be two definitions of the same
/// row shape. The column names below match that one deliberately, and both match
/// `0003_reminder_preferences.sql`.
abstract final class ReminderPreferencesDto {
  static const String tableName = 'reminder_preferences';

  static const String columnUserId = 'user_id';
  static const String columnDaysBefore = 'days_before';
  static const String columnTimeOfDay = 'time_of_day';
  static const String columnIsEnabled = 'is_enabled';

  static const String selectColumns =
      '$columnUserId, $columnDaysBefore, $columnTimeOfDay, $columnIsEnabled';

  /// Values for an upsert.
  ///
  /// An upsert rather than an update: nothing seeds this table at sign-up, so
  /// the first time a user changes a setting there is no row to update. That is
  /// also why `user_id` is included — it is the conflict target, and on an
  /// insert the row cannot be attributed without it.
  static Map<String, dynamic> toUpsert(
    ReminderPreferences preferences, {
    required String userId,
  }) => <String, dynamic>{
    columnUserId: userId,
    // Stored in the order they fire, furthest warning first. Postgres preserves
    // array order, so this is a real property of the row rather than a
    // convention the reader has to know about.
    columnDaysBefore: preferences.orderedOffsets,
    columnTimeOfDay: preferences.timeOfDay.toWireValue(),
    columnIsEnabled: preferences.isEnabled,
  };

  /// Reads a row into [ReminderPreferences].
  ///
  /// ## Every field falls back rather than throwing
  ///
  /// Unlike the bill and payment mappers, which throw on an unreadable row.
  /// The difference is what a failure costs: a bill that will not parse is a
  /// figure the user would otherwise believe, and silence there is dangerous. A
  /// reminder preference that will not parse is a *setting*, and the fallback is
  /// the documented column default — which is what a user with no row gets
  /// anyway, and is never wrong in a way that misstates money.
  ///
  /// Refusing to load would instead mean no reminders at all because one field
  /// was odd, which is the worse failure.
  static ReminderPreferences toEntity(Map<String, dynamic> row) {
    return ReminderPreferences(
      isEnabled: row[columnIsEnabled] as bool? ?? true,
      daysBefore: _offsets(row[columnDaysBefore]),
      timeOfDay:
          ReminderTime.tryParse(row[columnTimeOfDay] as String?) ??
          ReminderTime.defaultValue,
    );
  }

  /// Postgres `int[]` arrives as a `List<dynamic>`.
  ///
  /// Non-integers are dropped rather than defaulting the whole set: a stray
  /// value should cost that offset, not every reminder the user configured. An
  /// empty result falls back, because a set with nothing in it would mean no
  /// reminders while the row says they are on.
  static List<int> _offsets(Object? value) {
    if (value is! List) {
      return ReminderPreferences.defaultDaysBefore;
    }

    final List<int> offsets = value.whereType<int>().toList();

    return offsets.isEmpty ? ReminderPreferences.defaultDaysBefore : offsets;
  }
}
