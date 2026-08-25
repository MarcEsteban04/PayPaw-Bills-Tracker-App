import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/notifications/data/dtos/bill_reminder_override_dto.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';

/// The mapper between `public.bill_reminders` and the entity.
///
/// Hand-written, so every column name here is a string that the compiler will
/// never check against `0011_bill_reminders.sql`. A typo is a runtime failure on
/// a device, months later, and this is the only place it can be caught.
void main() {
  group('toUpsert', () {
    test('names the columns the migration declares', () {
      final Map<String, dynamic> values = BillReminderOverrideDto.toUpsert(
        const BillReminderOverride(
          billId: 'bill-1',
          isEnabled: false,
          daysBefore: <int>[1, 7],
          timeOfDay: ReminderTime(hour: 18, minute: 30),
        ),
        userId: 'user-1',
      );

      expect(values, <String, dynamic>{
        'bill_id': 'bill-1',
        'user_id': 'user-1',
        'days_before': <int>[7, 1],
        'time_of_day': '18:30:00',
        'is_enabled': false,
      });
    });

    test('sends nulls rather than omitting them', () {
      // The one that matters. A cleared field has to overwrite what is stored;
      // a map without the key would leave the old value in place, and the user
      // would have an override they believe they removed still firing at 6pm.
      final Map<String, dynamic> values = BillReminderOverrideDto.toUpsert(
        const BillReminderOverride(billId: 'bill-1', isEnabled: false),
        userId: 'user-1',
      );

      expect(values.keys, contains('days_before'));
      expect(values.keys, contains('time_of_day'));
      expect(values['days_before'], isNull);
      expect(values['time_of_day'], isNull);
    });

    test('sorts the offsets furthest-out first, like the defaults do', () {
      expect(
        BillReminderOverrideDto.toUpsert(
          const BillReminderOverride(
            billId: 'bill-1',
            daysBefore: <int>[0, 7, 3],
          ),
          userId: 'user-1',
        )['days_before'],
        <int>[7, 3, 0],
      );
    });

    test('does not sort the caller\'s own list underneath it', () {
      final List<int> chosen = <int>[0, 7, 3];

      BillReminderOverrideDto.toUpsert(
        BillReminderOverride(billId: 'bill-1', daysBefore: chosen),
        userId: 'user-1',
      );

      expect(chosen, <int>[0, 7, 3]);
    });

    test('carries the owner, since the upsert has no other way to say', () {
      // RLS checks `user_id = auth.uid()` on insert. Omitting it is not a
      // silent bug — it is every save failing — but it is worth pinning.
      expect(
        BillReminderOverrideDto.toUpsert(
          const BillReminderOverride(billId: 'bill-1', isEnabled: false),
          userId: 'user-9',
        )['user_id'],
        'user-9',
      );
    });
  });

  group('toEntity', () {
    test('reads a fully populated row', () {
      final BillReminderOverride override = BillReminderOverrideDto.toEntity(
        <String, dynamic>{
          'bill_id': 'bill-1',
          'days_before': <dynamic>[7, 1],
          'time_of_day': '18:30:00',
          'is_enabled': false,
        },
      );

      expect(override.billId, 'bill-1');
      expect(override.daysBefore, <int>[7, 1]);
      expect(override.timeOfDay, const ReminderTime(hour: 18, minute: 30));
      expect(override.isEnabled, isFalse);
    });

    test('a null column reads as inherit', () {
      final BillReminderOverride override = BillReminderOverrideDto.toEntity(
        <String, dynamic>{
          'bill_id': 'bill-1',
          'days_before': null,
          'time_of_day': null,
          'is_enabled': false,
        },
      );

      expect(override.daysBefore, isNull);
      expect(override.timeOfDay, isNull);
      expect(override.isEnabled, isFalse);
    });

    test('an unreadable time costs the time, not the row', () {
      // Falling back rather than throwing: a setting that will not parse should
      // cost that setting, and inherit is the safest wrong answer available —
      // it is what the user would get with no override at all.
      final BillReminderOverride override = BillReminderOverrideDto.toEntity(
        <String, dynamic>{
          'bill_id': 'bill-1',
          'time_of_day': 'half past six',
          'is_enabled': false,
        },
      );

      expect(override.timeOfDay, isNull);
      expect(override.isEnabled, isFalse);
    });

    test('an empty array reads as inherit, not as silence', () {
      // The column's check refuses an empty array, so one could only arrive
      // through a hand-written statement. Reading it as "no reminders" would
      // turn a malformed row into a bill never mentioned again.
      expect(
        BillReminderOverrideDto.toEntity(<String, dynamic>{
          'bill_id': 'bill-1',
          'days_before': <dynamic>[],
        }).daysBefore,
        isNull,
      );
    });

    test('a round trip through the wire keeps every field', () {
      const BillReminderOverride original = BillReminderOverride(
        billId: 'bill-1',
        isEnabled: false,
        daysBefore: <int>[7, 1],
        timeOfDay: ReminderTime(hour: 18, minute: 30),
      );

      final Map<String, dynamic> row = BillReminderOverrideDto.toUpsert(
        original,
        userId: 'user-1',
      );

      expect(BillReminderOverrideDto.toEntity(row), original);
    });
  });
}
