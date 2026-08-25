import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/reminder_time.dart';

/// Maps a `public.bill_reminders` row to [BillReminderOverride].
///
/// Column names have to match `supabase/migrations/0011_bill_reminders.sql`
/// exactly, and a mismatch is a runtime failure rather than a compile error —
/// which is the whole reason a hand-written mapper gets its own test.
abstract final class BillReminderOverrideDto {
  static const String tableName = 'bill_reminders';

  static const String columnBillId = 'bill_id';
  static const String columnUserId = 'user_id';
  static const String columnDaysBefore = 'days_before';
  static const String columnTimeOfDay = 'time_of_day';
  static const String columnIsEnabled = 'is_enabled';

  static const String selectColumns =
      '$columnBillId, $columnDaysBefore, $columnTimeOfDay, $columnIsEnabled';

  /// Values for an upsert, keyed on the bill.
  ///
  /// **Nulls are sent, not omitted.** A field cleared back to "inherit" has to
  /// overwrite what was stored, and a map without the key would leave the old
  /// value in place — an override the user thought they had removed, still
  /// quietly firing at 6pm.
  static Map<String, dynamic> toUpsert(
    BillReminderOverride override, {
    required String userId,
  }) => <String, dynamic>{
    columnBillId: override.billId,
    columnUserId: userId,
    columnDaysBefore: override.daysBefore == null
        ? null
        : (List<int>.of(override.daysBefore!)
            ..sort((int a, int b) => b.compareTo(a))),
    columnTimeOfDay: override.timeOfDay?.toWireValue(),
    columnIsEnabled: override.isEnabled,
  };

  /// Reads a row.
  ///
  /// Falls back rather than throwing, like the defaults mapper next door: a
  /// setting that will not parse should cost that setting, not the whole
  /// schedule. An unreadable field reads as null, which means inherit — the
  /// safest wrong answer available, since it is what the user would get with no
  /// override at all.
  static BillReminderOverride toEntity(Map<String, dynamic> row) {
    return BillReminderOverride(
      billId: row[columnBillId] as String? ?? '',
      isEnabled: row[columnIsEnabled] as bool?,
      daysBefore: _offsets(row[columnDaysBefore]),
      timeOfDay: ReminderTime.tryParse(row[columnTimeOfDay] as String?),
    );
  }

  /// Postgres `int[]` arrives as a `List<dynamic>`.
  ///
  /// An empty array reads as null — inherit — rather than as "no reminders at
  /// all". The column's own check refuses an empty array, so one could only
  /// arrive through a hand-written statement, and reading it as silence would
  /// turn a malformed row into a bill that is never mentioned again.
  static List<int>? _offsets(Object? value) {
    if (value is! List) {
      return null;
    }

    final List<int> offsets = value.whereType<int>().toList();

    return offsets.isEmpty ? null : offsets;
  }
}
