import 'package:meta/meta.dart';

/// A time of day with no date and no zone — 09:00, meaning "nine in the
/// morning, wherever the user is".
///
/// Not `TimeOfDay`: that lives in `package:flutter`, and the domain layer does
/// not import Flutter. Not `DateTime` either, which would carry a meaningless
/// date and drag a timezone into a value that deliberately has none — the zone
/// is a separate, explicit setting.
@immutable
class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour < 24, 'hour must be 0-23'),
      assert(minute >= 0 && minute < 60, 'minute must be 0-59');

  /// 09:00 — the default in `0003_reminder_preferences.sql`.
  ///
  /// Repeated here rather than read from the row, because the form needs a value
  /// before any row exists. The two are pinned together by a test.
  static const ReminderTime defaultValue = ReminderTime(hour: 9, minute: 0);

  /// Parses Postgres `time` — `09:00:00`, and tolerating `09:00`.
  static ReminderTime? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }

    return ReminderTime(hour: hour, minute: minute);
  }

  final int hour;
  final int minute;

  /// `HH:MM:SS`, which is what a Postgres `time` column expects.
  String toWireValue() => '${_pad(hour)}:${_pad(minute)}:00';

  /// Minutes since midnight. The whole value in one comparable number.
  int get minutesSinceMidnight => hour * 60 + minute;

  static String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  int compareTo(ReminderTime other) =>
      minutesSinceMidnight.compareTo(other.minutesSinceMidnight);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'ReminderTime(${_pad(hour)}:${_pad(minute)})';
}
