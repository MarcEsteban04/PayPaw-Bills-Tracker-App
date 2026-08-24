import 'package:meta/meta.dart';

import 'reminder_time.dart';

/// How far ahead a user wants warning, and at what time of day.
///
/// One row per user in `reminder_preferences`, or **no row at all** — which is
/// the common case and means "the defaults". The table deliberately seeds
/// nothing at signup, so absence and "unchanged" are the same state and there is
/// one definition of the default rather than a table full of rows repeating it.
///
/// The values here mirror that migration's column defaults. They are pinned to
/// it by a test, because two definitions of "three days out" that drift are a
/// user being reminded on a day nobody chose.
@immutable
class ReminderPreferences {
  const ReminderPreferences({
    this.isEnabled = true,
    this.daysBefore = defaultDaysBefore,
    this.timeOfDay = ReminderTime.defaultValue,
  });

  /// What a user with no row gets: three days out, the day before, and the day
  /// itself.
  static const List<int> defaultDaysBefore = <int>[3, 1, 0];

  /// The column's CHECK allows one to five offsets.
  static const int maxOffsets = 5;

  /// And the app's own bound on how far out an offset may be. The column has no
  /// CHECK for this — a constraint validating array *elements* would need a
  /// subquery — so it is enforced here, as that migration's comment says.
  static const int maxDaysBefore = 60;

  /// Whether the user wants reminders at all.
  ///
  /// Distinct from the operating system's permission: this is the user asking
  /// PayPaw not to, which it should honour even where Android would allow it.
  final bool isEnabled;

  /// Days before the due date to warn. `0` is the due date itself.
  final List<int> daysBefore;

  final ReminderTime timeOfDay;

  /// The offsets in the order they actually fire — furthest warning first.
  ///
  /// Sorted here rather than trusted from the row, because the column is an
  /// array with no ordering guarantee and nothing stops `{0,3,1}` being stored.
  /// Duplicates are dropped: `{3,3,1}` is two reminders on the same day at the
  /// same minute, which is one reminder and one annoyance.
  List<int> get orderedOffsets =>
      (daysBefore.toSet().toList()..sort()).reversed.toList();

  /// Whether this is a value the database will accept.
  bool get isValid =>
      daysBefore.isNotEmpty &&
      daysBefore.length <= maxOffsets &&
      daysBefore.every((int days) => days >= 0 && days <= maxDaysBefore);

  ReminderPreferences copyWith({
    bool? isEnabled,
    List<int>? daysBefore,
    ReminderTime? timeOfDay,
  }) => ReminderPreferences(
    isEnabled: isEnabled ?? this.isEnabled,
    daysBefore: daysBefore ?? this.daysBefore,
    timeOfDay: timeOfDay ?? this.timeOfDay,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderPreferences &&
      other.isEnabled == isEnabled &&
      other.timeOfDay == timeOfDay &&
      _sameOffsets(other.daysBefore, daysBefore);

  @override
  int get hashCode =>
      Object.hash(isEnabled, timeOfDay, Object.hashAll(orderedOffsets));

  static bool _sameOffsets(List<int> a, List<int> b) {
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
      'ReminderPreferences(enabled: $isEnabled, $daysBefore at $timeOfDay)';
}
