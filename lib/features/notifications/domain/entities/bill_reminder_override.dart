import 'package:meta/meta.dart';

import 'reminder_preferences.dart';
import 'reminder_time.dart';

/// One bill's departure from the user's reminder defaults.
///
/// ## Every field is nullable, and null means inherit
///
/// That is the whole design of `bill_reminders`, and the reason it is a separate
/// table rather than three more columns on `bills`. An override that had to
/// restate every setting would drift from the defaults the moment the defaults
/// changed: turn the reminder time from 9am to 6pm and every bill that had ever
/// been touched would stay at nine, silently, forever.
///
/// So a bill that only wants a different *time* stores a time and nothing else,
/// and keeps following the defaults for the rest.
///
/// A row overriding nothing should not exist — the table has a check constraint
/// saying so. [isEmpty] is the app-side reading of the same rule, and the reason
/// saving an override that matches the defaults deletes the row instead.
@immutable
class BillReminderOverride {
  const BillReminderOverride({
    required this.billId,
    this.isEnabled,
    this.daysBefore,
    this.timeOfDay,
  });

  final String billId;

  /// Whether this bill is reminded about at all.
  ///
  /// The common override, and the one worth having on its own: a bill on
  /// auto-debit does not need warning about, and silencing it should not mean
  /// silencing every other bill too.
  final bool? isEnabled;

  final List<int>? daysBefore;
  final ReminderTime? timeOfDay;

  /// Whether this overrides nothing, and so should not be stored.
  bool get isEmpty =>
      isEnabled == null && daysBefore == null && timeOfDay == null;

  /// The rules this bill actually follows.
  ///
  /// Field by field, because that is what "null means inherit" means. Resolving
  /// wholesale — take the override if any field is set, otherwise the defaults —
  /// would silently drop the other two settings, which is the bug this shape
  /// exists to make impossible.
  ReminderPreferences resolve(ReminderPreferences defaults) =>
      ReminderPreferences(
        isEnabled: isEnabled ?? defaults.isEnabled,
        daysBefore: daysBefore ?? defaults.daysBefore,
        timeOfDay: timeOfDay ?? defaults.timeOfDay,
      );

  BillReminderOverride copyWith({
    bool? isEnabled,
    List<int>? daysBefore,
    ReminderTime? timeOfDay,
    bool clearEnabled = false,
    bool clearDays = false,
    bool clearTime = false,
  }) => BillReminderOverride(
    billId: billId,
    isEnabled: clearEnabled ? null : (isEnabled ?? this.isEnabled),
    daysBefore: clearDays ? null : (daysBefore ?? this.daysBefore),
    timeOfDay: clearTime ? null : (timeOfDay ?? this.timeOfDay),
  );

  @override
  bool operator ==(Object other) =>
      other is BillReminderOverride &&
      other.billId == billId &&
      other.isEnabled == isEnabled &&
      other.timeOfDay == timeOfDay &&
      _sameDays(other.daysBefore, daysBefore);

  @override
  int get hashCode => Object.hash(
    billId,
    isEnabled,
    timeOfDay,
    daysBefore == null ? null : Object.hashAll(daysBefore!),
  );

  static bool _sameDays(List<int>? a, List<int>? b) {
    if (a == null || b == null) {
      return a == b;
    }
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  @override
  String toString() =>
      'BillReminderOverride($billId, enabled: $isEnabled, '
      'days: $daysBefore, at: $timeOfDay)';
}
