import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/onboarding/domain/entities/account_setup.dart';
import 'package:paypaw/features/onboarding/domain/entities/reminder_time.dart';
import 'package:paypaw/features/onboarding/domain/entities/setup_options.dart';

void main() {
  group('ReminderTime', () {
    test('formats as a Postgres time', () {
      expect(const ReminderTime(hour: 9, minute: 0).toWireValue(), '09:00:00');
      expect(
        const ReminderTime(hour: 21, minute: 30).toWireValue(),
        '21:30:00',
      );
      expect(const ReminderTime(hour: 0, minute: 5).toWireValue(), '00:05:00');
    });

    test('parses what Postgres returns', () {
      expect(
        ReminderTime.tryParse('09:00:00'),
        const ReminderTime(hour: 9, minute: 0),
      );
      // Some drivers drop the seconds.
      expect(
        ReminderTime.tryParse('21:30'),
        const ReminderTime(hour: 21, minute: 30),
      );
    });

    test('returns null rather than guessing', () {
      for (final String? input in <String?>[
        null,
        '',
        'nine',
        '25:00:00',
        '09:70',
        '9',
      ]) {
        expect(
          ReminderTime.tryParse(input),
          isNull,
          reason: '"$input" should not parse',
        );
      }
    });

    test('round-trips', () {
      const ReminderTime original = ReminderTime(hour: 17, minute: 45);

      expect(ReminderTime.tryParse(original.toWireValue()), original);
    });

    test('the default matches the column default', () {
      // 0003_reminder_preferences.sql: `time_of_day time not null default
      // '09:00'`. The form needs a value before any row exists, so the default
      // is stated in two places; this is what keeps them the same.
      expect(ReminderTime.defaultValue.toWireValue(), '09:00:00');
    });

    test('sorts by time of day', () {
      final List<ReminderTime> times = <ReminderTime>[
        const ReminderTime(hour: 21, minute: 0),
        const ReminderTime(hour: 6, minute: 30),
        const ReminderTime(hour: 9, minute: 0),
      ]..sort();

      expect(times.first, const ReminderTime(hour: 6, minute: 30));
      expect(times.last, const ReminderTime(hour: 21, minute: 0));
    });
  });

  group('AccountSetup defaults', () {
    test('match the column defaults exactly', () {
      // The whole reason "skip" is safe: it writes these, and these are what the
      // database would have used anyway. If a column default changes and this
      // does not, a skipped account stops matching a defaulted one.
      const AccountSetup setup = AccountSetup();

      expect(setup.currency, 'PHP');
      expect(setup.timeZone, 'Asia/Manila');
      expect(setup.reminderDaysBefore, <int>[3, 1, 0]);
      expect(setup.reminderTime, const ReminderTime(hour: 9, minute: 0));
      expect(setup.remindersEnabled, isTrue);
    });

    test('are valid', () {
      expect(const AccountSetup().isValid, isTrue);
    });
  });

  group('validity mirrors the column constraints', () {
    test('currency must be three uppercase letters', () {
      // profiles.currency is char(3) with a ~ '^[A-Z]{3}$' check.
      expect(const AccountSetup(currency: 'php').isValid, isFalse);
      expect(const AccountSetup(currency: 'PH').isValid, isFalse);
      expect(const AccountSetup(currency: 'PHPP').isValid, isFalse);
      expect(const AccountSetup(currency: 'USD').isValid, isTrue);
    });

    test('reminder days must be one to five', () {
      // reminder_preferences.days_before has a
      // `array_length(days_before, 1) between 1 and 5` check.
      expect(const AccountSetup(reminderDaysBefore: <int>[]).isValid, isFalse);
      expect(
        const AccountSetup(reminderDaysBefore: <int>[14, 7, 3, 2, 1, 0])
            .isValid,
        isFalse,
      );
      expect(const AccountSetup(reminderDaysBefore: <int>[7]).isValid, isTrue);
    });

    test('a negative reminder offset is not a thing', () {
      expect(
        const AccountSetup(reminderDaysBefore: <int>[-1]).isValid,
        isFalse,
      );
    });
  });

  group('toggleReminderDay', () {
    test('adds a day and keeps the list ordered furthest-first', () {
      final AccountSetup result = const AccountSetup(
        reminderDaysBefore: <int>[1, 0],
      ).toggleReminderDay(7);

      expect(result.reminderDaysBefore, <int>[7, 1, 0]);
    });

    test('removes a day that was on', () {
      final AccountSetup result = const AccountSetup(
        reminderDaysBefore: <int>[7, 3, 1],
      ).toggleReminderDay(3);

      expect(result.reminderDaysBefore, <int>[7, 1]);
    });

    test('refuses to empty the list', () {
      // "Reminders on, but never" is not a state worth having, and the column's
      // CHECK forbids it. Turning them all off is what the switch is for.
      const AccountSetup one = AccountSetup(reminderDaysBefore: <int>[1]);

      expect(one.toggleReminderDay(1), same(one));
    });

    test('refuses a sixth day', () {
      const AccountSetup full = AccountSetup(
        reminderDaysBefore: <int>[14, 7, 3, 1, 0],
      );

      expect(full.toggleReminderDay(2), same(full));
      expect(full.isValid, isTrue);
    });

    test('never produces an invalid value', () {
      // The point of the guard clauses: the form cannot build something the
      // insert will reject.
      AccountSetup setup = const AccountSetup();

      for (final int days in <int>[7, 3, 1, 0, 14, 2, 5, 7, 3]) {
        setup = setup.toggleReminderDay(days);
        expect(setup.isValid, isTrue, reason: 'after toggling $days');
      }
    });
  });

  group('equality', () {
    test('compares the day list by value, not by identity', () {
      // Two lists with the same contents are different objects, so the default
      // List equality would make every state change look like a change.
      expect(
        const AccountSetup(reminderDaysBefore: <int>[3, 1]),
        const AccountSetup(reminderDaysBefore: <int>[3, 1]),
      );
      expect(
        const AccountSetup(reminderDaysBefore: <int>[3, 1]).hashCode,
        const AccountSetup(reminderDaysBefore: <int>[3, 1]).hashCode,
      );
      expect(
        const AccountSetup(reminderDaysBefore: <int>[3, 1]),
        isNot(const AccountSetup(reminderDaysBefore: <int>[1, 3])),
      );
    });
  });

  group('SetupOptions', () {
    test('every default is present in its own list', () {
      // The dropdowns select by matching the current value against their items.
      // A default absent from the list would leave the field showing nothing on
      // the very first screen of the app.
      expect(
        SetupOptions.currencies.map((CurrencyOption o) => o.code),
        contains(AccountSetup.defaultCurrency),
      );
      expect(
        SetupOptions.timeZones.map((TimeZoneOption o) => o.name),
        contains(AccountSetup.defaultTimeZone),
      );
    });

    test('every guess is also present', () {
      // A guess the dropdown cannot display is worse than no guess.
      final Set<String> codes = SetupOptions.currencies
          .map((CurrencyOption o) => o.code)
          .toSet();
      final Set<String> zones = SetupOptions.timeZones
          .map((TimeZoneOption o) => o.name)
          .toSet();

      for (final String country in <String>[
        'PH',
        'US',
        'GB',
        'JP',
        'SG',
        'DE',
        'AE',
      ]) {
        expect(
          codes,
          contains(SetupOptions.currencyForCountry(country)),
          reason: 'the guess for $country is not in the list',
        );
      }

      for (final int minutes in <int>[480, 540, 0, -300, -480, 240]) {
        expect(
          zones,
          contains(SetupOptions.timeZoneForOffset(Duration(minutes: minutes))),
          reason: 'the guess for offset $minutes is not in the list',
        );
      }
    });

    test('an unknown country or offset gives no answer', () {
      // Null means "fall back to the column default", which is obviously wrong
      // to the user and therefore gets corrected. A confident wrong guess does
      // not.
      expect(SetupOptions.currencyForCountry(null), isNull);
      expect(SetupOptions.currencyForCountry('ZZ'), isNull);
      expect(
        SetupOptions.timeZoneForOffset(const Duration(minutes: 345)),
        isNull,
      );
    });

    test('the currency guess is case-insensitive', () {
      expect(SetupOptions.currencyForCountry('ph'), 'PHP');
    });

    test('currency codes are unique and well formed', () {
      final List<String> codes = SetupOptions.currencies
          .map((CurrencyOption o) => o.code)
          .toList();

      expect(codes.toSet().length, codes.length, reason: 'duplicate currency');
      for (final String code in codes) {
        expect(RegExp(r'^[A-Z]{3}$').hasMatch(code), isTrue, reason: code);
      }
    });

    test('reminder choices are offered furthest-first', () {
      final List<int> choices = SetupOptions.reminderDayChoices;

      expect(
        choices,
        contains(0),
        reason: 'the due date itself must be offered',
      );
      expect(
        choices,
        orderedEquals(List<int>.of(choices)..sort((int a, int b) => b - a)),
      );
      expect(choices.length, lessThanOrEqualTo(AccountSetup.maxDaysBefore));
    });
  });
}
