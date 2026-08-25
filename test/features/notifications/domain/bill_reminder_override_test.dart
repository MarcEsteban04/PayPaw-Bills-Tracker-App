import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_time.dart';

/// One bill's departure from the defaults.
///
/// The whole type is one idea — null means inherit — and every test here is a
/// way of getting that wrong. Resolving wholesale rather than field by field is
/// the dangerous one: it compiles, it reads correctly, and it silently freezes
/// two settings at whatever they were the day the bill was touched.
void main() {
  // The column defaults: three days out, one day out, and on the day, at 09:00.
  // Left as the constructor's own so this stays true if they ever move.
  const ReminderPreferences defaults = ReminderPreferences();

  const ReminderTime sixPm = ReminderTime(hour: 18, minute: 0);

  group('isEmpty', () {
    test('an override with no fields set overrides nothing', () {
      expect(const BillReminderOverride(billId: 'bill-1').isEmpty, isTrue);
    });

    test('any single field set is enough to be worth storing', () {
      expect(
        const BillReminderOverride(billId: 'bill-1', isEnabled: false).isEmpty,
        isFalse,
      );
      expect(
        const BillReminderOverride(
          billId: 'bill-1',
          daysBefore: <int>[7],
        ).isEmpty,
        isFalse,
      );
      expect(
        const BillReminderOverride(billId: 'bill-1', timeOfDay: sixPm).isEmpty,
        isFalse,
      );
    });

    test('silencing a bill counts, even though false looks like absence', () {
      // The one that would break under a `?? ` -style emptiness check: `false`
      // is the most common override there is, and reading it as unset would
      // delete the row and start reminding the user about a bill on auto-debit.
      const BillReminderOverride silenced = BillReminderOverride(
        billId: 'bill-1',
        isEnabled: false,
      );

      expect(silenced.isEmpty, isFalse);
      expect(silenced.resolve(defaults).isEnabled, isFalse);
    });
  });

  group('resolve', () {
    test('an unset field follows the defaults', () {
      final ReminderPreferences rules = const BillReminderOverride(
        billId: 'bill-1',
        timeOfDay: sixPm,
      ).resolve(defaults);

      expect(rules.timeOfDay, sixPm);
      expect(rules.daysBefore, defaults.daysBefore);
      expect(rules.isEnabled, defaults.isEnabled);
    });

    test('a bill that overrides one field tracks changes to the others', () {
      // The reason the fields are nullable at all. The user moves their default
      // reminder to 6pm; a bill that only ever asked for a different set of days
      // moves with it rather than staying at nine forever.
      const BillReminderOverride override = BillReminderOverride(
        billId: 'bill-1',
        daysBefore: <int>[7],
      );

      expect(override.resolve(defaults).timeOfDay, defaults.timeOfDay);
      expect(
        override.resolve(defaults.copyWith(timeOfDay: sixPm)).timeOfDay,
        sixPm,
      );
    });

    test('every field set means the defaults are ignored entirely', () {
      final ReminderPreferences rules = const BillReminderOverride(
        billId: 'bill-1',
        isEnabled: false,
        daysBefore: <int>[14],
        timeOfDay: sixPm,
      ).resolve(defaults);

      expect(rules.isEnabled, isFalse);
      expect(rules.daysBefore, <int>[14]);
      expect(rules.timeOfDay, sixPm);
    });
  });

  group('copyWith', () {
    const BillReminderOverride full = BillReminderOverride(
      billId: 'bill-1',
      isEnabled: false,
      daysBefore: <int>[7],
      timeOfDay: sixPm,
    );

    test('leaves untouched fields alone', () {
      expect(full.copyWith(isEnabled: true).daysBefore, <int>[7]);
      expect(full.copyWith(isEnabled: true).timeOfDay, sixPm);
    });

    test('clearing a field returns it to inherit', () {
      // Distinct from passing null, which `copyWith` cannot tell from "not
      // given" — hence the explicit flags.
      expect(full.copyWith(clearTime: true).timeOfDay, isNull);
      expect(full.copyWith(clearTime: true).isEnabled, isFalse);
    });

    test('clearing every field leaves an override worth deleting', () {
      expect(
        full
            .copyWith(clearEnabled: true, clearDays: true, clearTime: true)
            .isEmpty,
        isTrue,
      );
    });

    test('the bill it belongs to cannot be changed', () {
      expect(full.copyWith(isEnabled: true).billId, 'bill-1');
    });
  });

  group('equality', () {
    test('compares the day list by value, not by identity', () {
      expect(
        BillReminderOverride(billId: 'bill-1', daysBefore: <int>[3, 1]),
        BillReminderOverride(billId: 'bill-1', daysBefore: <int>[3, 1]),
      );
    });

    test('an unset list is not an empty one', () {
      expect(
        const BillReminderOverride(billId: 'bill-1'),
        isNot(
          BillReminderOverride(billId: 'bill-1', daysBefore: const <int>[]),
        ),
      );
    });

    test('order matters, because it is the order they were chosen in', () {
      expect(
        BillReminderOverride(billId: 'bill-1', daysBefore: <int>[3, 1]),
        isNot(BillReminderOverride(billId: 'bill-1', daysBefore: <int>[1, 3])),
      );
    });
  });
}
