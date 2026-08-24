import 'package:meta/meta.dart';

import '../../../notifications/domain/entities/reminder_time.dart';

/// The answers onboarding collects, as one value.
///
/// Every field maps to a column that already exists — `profiles.currency`,
/// `profiles.time_zone`, and the three on `reminder_preferences`. That is the
/// whole reason this screen is setup rather than a feature tour: it leaves
/// something behind.
///
/// The defaults are the *column* defaults, so skipping onboarding and completing
/// it without changing anything produce the same account.
@immutable
class AccountSetup {
  const AccountSetup({
    this.currency = defaultCurrency,
    this.timeZone = defaultTimeZone,
    this.remindersEnabled = true,
    this.reminderDaysBefore = defaultDaysBefore,
    this.reminderTime = ReminderTime.defaultValue,
  });

  /// Matches `profiles.currency`'s default.
  static const String defaultCurrency = 'PHP';

  /// Matches `profiles.time_zone`'s default.
  static const String defaultTimeZone = 'Asia/Manila';

  /// Matches `reminder_preferences.days_before`'s default: three days out, the
  /// day before, and the day itself.
  static const List<int> defaultDaysBefore = <int>[3, 1, 0];

  /// The column's CHECK allows one to five entries. Enforced here too, so the
  /// form cannot build a value the database will reject.
  static const int maxDaysBefore = 5;

  /// ISO 4217, uppercase. `char(3)` with a `^[A-Z]{3}$` check.
  final String currency;

  /// An IANA zone name — `Asia/Manila`, not `PST` and not an offset. Offsets
  /// change twice a year in half the world; a zone name does not.
  final String timeZone;

  final bool remindersEnabled;

  /// Days before the due date to send a reminder. `0` means the due date itself.
  ///
  /// Held sorted descending — furthest warning first — which is the order the
  /// reminders actually fire in and the order the form shows them in.
  final List<int> reminderDaysBefore;

  final ReminderTime reminderTime;

  /// Whether this is a value the database will accept.
  ///
  /// Mirrors the column constraints rather than restating them loosely: an
  /// invalid value should fail here, in a form the user can fix, and not as a
  /// constraint violation after a round trip.
  bool get isValid =>
      RegExp(r'^[A-Z]{3}$').hasMatch(currency) &&
      timeZone.isNotEmpty &&
      reminderDaysBefore.isNotEmpty &&
      reminderDaysBefore.length <= maxDaysBefore &&
      reminderDaysBefore.every((int days) => days >= 0);

  AccountSetup copyWith({
    String? currency,
    String? timeZone,
    bool? remindersEnabled,
    List<int>? reminderDaysBefore,
    ReminderTime? reminderTime,
  }) => AccountSetup(
    currency: currency ?? this.currency,
    timeZone: timeZone ?? this.timeZone,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    reminderTime: reminderTime ?? this.reminderTime,
  );

  /// Adds or removes one reminder day, keeping the list sorted and within the
  /// column's limit.
  ///
  /// Returns `this` when the change is not allowed — turning off the last
  /// remaining day, or adding a sixth — so a chip that cannot be toggled simply
  /// does nothing instead of producing a value the insert will reject.
  AccountSetup toggleReminderDay(int days) {
    final List<int> next = reminderDaysBefore.toList();

    if (next.remove(days)) {
      // Never empty: "reminders on, but never" is not a state worth having, and
      // the column's CHECK forbids it anyway. Turning them all off is what the
      // enabled switch is for.
      return next.isEmpty ? this : copyWith(reminderDaysBefore: next);
    }

    if (next.length >= maxDaysBefore) {
      return this;
    }

    next
      ..add(days)
      ..sort((int a, int b) => b.compareTo(a));

    return copyWith(reminderDaysBefore: next);
  }

  @override
  bool operator ==(Object other) =>
      other is AccountSetup &&
      other.currency == currency &&
      other.timeZone == timeZone &&
      other.remindersEnabled == remindersEnabled &&
      other.reminderTime == reminderTime &&
      _sameDays(other.reminderDaysBefore, reminderDaysBefore);

  @override
  int get hashCode => Object.hash(
    currency,
    timeZone,
    remindersEnabled,
    reminderTime,
    Object.hashAll(reminderDaysBefore),
  );

  static bool _sameDays(List<int> a, List<int> b) {
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
}
