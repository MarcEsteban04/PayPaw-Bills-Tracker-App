import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/onboarding/data/dtos/account_setup_dto.dart';
import 'package:paypaw/features/onboarding/domain/entities/account_setup.dart';
import 'package:paypaw/features/onboarding/domain/entities/reminder_time.dart';

void main() {
  const AccountSetup setup = AccountSetup(
    currency: 'USD',
    timeZone: 'America/New_York',
    reminderDaysBefore: <int>[7, 1],
    reminderTime: ReminderTime(hour: 18, minute: 30),
  );

  group('the profiles half', () {
    test('sends the two columns onboarding owns', () {
      final Map<String, dynamic> values = AccountSetupDto.toProfileUpdate(
        setup,
      );

      expect(values['currency'], 'USD');
      expect(values['time_zone'], 'America/New_York');
      expect(values.length, 2);
    });

    test('does not send the primary key', () {
      // `id` is what the row is matched on and what the RLS policy compares
      // against. Sending it would be an update the policy has to reject rather
      // than one it never sees.
      expect(AccountSetupDto.toProfileUpdate(setup).containsKey('id'), isFalse);
    });

    test('uppercases the currency', () {
      // The column is char(3) with a ~ '^[A-Z]{3}$' check, so a lowercase code
      // is a constraint violation rather than a value that gets normalised.
      expect(
        AccountSetupDto.toProfileUpdate(
          const AccountSetup(currency: 'php'),
        )['currency'],
        'PHP',
      );
    });
  });

  group('the reminder_preferences half', () {
    test('sends every column, including the owner', () {
      // Unlike the profile update, this one may be an insert — the row is not
      // created at sign-up — so it has to carry user_id.
      final Map<String, dynamic> values = AccountSetupDto.toReminderUpsert(
        setup,
        userId: 'user-1',
      );

      expect(values['user_id'], 'user-1');
      expect(values['days_before'], <int>[7, 1]);
      expect(values['time_of_day'], '18:30:00');
      expect(values['is_enabled'], isTrue);
    });

    test('sends the time as a Postgres time, not an ISO timestamp', () {
      expect(
        AccountSetupDto.toReminderUpsert(
          const AccountSetup(),
          userId: 'user-1',
        )['time_of_day'],
        '09:00:00',
      );
    });

    test('sorts the days furthest-first', () {
      // Postgres preserves array order, so the stored order is a real property
      // of the row — and the order they fire in is the only one that reads
      // correctly when the row is looked at later.
      final Map<String, dynamic> values = AccountSetupDto.toReminderUpsert(
        const AccountSetup(reminderDaysBefore: <int>[0, 7, 1]),
        userId: 'user-1',
      );

      expect(values['days_before'], <int>[7, 1, 0]);
    });

    test('does not mutate the entity while sorting', () {
      // The sort is on a copy. Sorting in place would edit a value the UI is
      // still rendering, from inside the data layer.
      const AccountSetup unsorted = AccountSetup(
        reminderDaysBefore: <int>[0, 7, 1],
      );

      AccountSetupDto.toReminderUpsert(unsorted, userId: 'user-1');

      expect(unsorted.reminderDaysBefore, <int>[0, 7, 1]);
    });

    test('carries the disabled flag rather than dropping the row', () {
      // Reminders off is a row saying so, not an absent row. An absent row is
      // indistinguishable from "never asked", and the two need different
      // handling in Phase 8.
      expect(
        AccountSetupDto.toReminderUpsert(
          const AccountSetup(remindersEnabled: false),
          userId: 'user-1',
        )['is_enabled'],
        isFalse,
      );
    });
  });

  group('column names against the migrations', () {
    // The check that actually catches the dangerous mistake. Every name below is
    // a string the compiler cannot verify, and a wrong one fails at runtime on
    // the last screen of sign-up. Reading the migration is the only way to know.
    String migration(String name) {
      final File file = File('supabase/migrations/$name');
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${file.path} is missing — run this from the project root, or the '
            'migration was renamed and this test needs updating',
      );
      return file.readAsStringSync();
    }

    test('every profiles column exists in 0002_profiles.sql', () {
      final String sql = migration('0002_profiles.sql');

      for (final String column in <String>[
        AccountSetupDto.columnProfileId,
        AccountSetupDto.columnCurrency,
        AccountSetupDto.columnTimeZone,
      ]) {
        expect(
          sql,
          contains(column),
          reason: '$column is written but not declared in 0002_profiles.sql',
        );
      }
    });

    test('every reminder column exists in 0003_reminder_preferences.sql', () {
      final String sql = migration('0003_reminder_preferences.sql');

      for (final String column in <String>[
        AccountSetupDto.columnUserId,
        AccountSetupDto.columnDaysBefore,
        AccountSetupDto.columnTimeOfDay,
        AccountSetupDto.columnIsEnabled,
      ]) {
        expect(
          sql,
          contains(column),
          reason:
              '$column is written but not declared in '
              '0003_reminder_preferences.sql',
        );
      }
    });

    test('both table names exist too', () {
      expect(
        migration('0002_profiles.sql'),
        contains('public.${AccountSetupDto.profilesTable}'),
      );
      expect(
        migration('0003_reminder_preferences.sql'),
        contains('public.${AccountSetupDto.reminderPreferencesTable}'),
      );
    });

    test('the entity defaults still match the column defaults', () {
      // Stated in Dart because the form needs them before a row exists. This is
      // what stops the two copies drifting — and drift here means a skipped
      // account stops matching a defaulted one.
      expect(
        migration('0002_profiles.sql'),
        contains("default '${AccountSetup.defaultCurrency}'"),
      );
      expect(
        migration('0002_profiles.sql'),
        contains("default '${AccountSetup.defaultTimeZone}'"),
      );
      expect(
        migration('0003_reminder_preferences.sql'),
        contains(
          "default '{${AccountSetup.defaultDaysBefore.join(',')}}'::int[]",
        ),
      );
    });
  });
}
