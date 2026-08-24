import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/bills/domain/validation/bill_validators.dart';

void main() {
  // Fixed rather than DateTime.now(): the validators take `today` as an argument
  // precisely so tests do not have to mock the clock, and a test that drifts with
  // the calendar is a test that fails one day for no reason.
  final DateTime today = DateTime(2026, 8, 24);

  group('name', () {
    test('accepts an ordinary name', () {
      expect(BillValidators.name('Meralco electricity'), isNull);
    });

    test('requires something', () {
      expect(BillValidators.name(''), isNotNull);
      expect(BillValidators.name('   '), isNotNull);
      expect(BillValidators.name(null), isNotNull);
    });

    test('matches the column limit', () {
      expect(BillValidators.name('a' * BillValidators.maxNameLength), isNull);
      expect(
        BillValidators.name('a' * (BillValidators.maxNameLength + 1)),
        isNotNull,
      );
    });
  });

  group('amount', () {
    test('accepts amounts a person would type', () {
      for (final String input in <String>[
        '1250.50',
        '1,250.50',
        '1250',
        '0.01',
        ' 999.99 ',
      ]) {
        expect(
          BillValidators.amount(input),
          isNull,
          reason: '"$input" should be accepted',
        );
      }
    });

    test('requires a value', () {
      expect(BillValidators.amount(''), isNotNull);
      expect(BillValidators.amount(null), isNotNull);
    });

    test('rejects zero, unlike the column', () {
      // The column permits 0 so an import can carry odd historical data. A person
      // typing into a form should not be able to create a bill that can never be
      // paid or cleared.
      expect(BillValidators.amount('0'), isNotNull);
      expect(BillValidators.amount('0.00'), isNotNull);
    });

    test('rejects a negative', () {
      expect(BillValidators.amount('-50'), isNotNull);
    });

    test('rejects what is not a number', () {
      for (final String input in <String>['abc', '12.345', r'50$', '1.2.3']) {
        expect(
          BillValidators.amount(input),
          isNotNull,
          reason: '"$input" should be rejected',
        );
      }
    });
  });

  group('due date', () {
    test('accepts today, the near future and the recent past', () {
      expect(BillValidators.dueDate(today, today: today), isNull);
      expect(
        BillValidators.dueDate(DateTime(2026, 12, 31), today: today),
        isNull,
      );
      // A bill someone forgot last year is a real thing to record.
      expect(
        BillValidators.dueDate(DateTime(2025, 3, 15), today: today),
        isNull,
      );
    });

    test('requires a date', () {
      expect(BillValidators.dueDate(null, today: today), isNotNull);
    });

    test('catches a mistyped year', () {
      // The actual failure this bound exists for: 2062 instead of 2026.
      final String? message = BillValidators.dueDate(
        DateTime(2062, 8, 24),
        today: today,
      );

      expect(message, isNotNull);
      expect(message, contains('year'));
    });

    test('rejects a date implausibly far in the past', () {
      expect(
        BillValidators.dueDate(DateTime(1999, 1, 2), today: today),
        isNotNull,
      );
    });

    test('is inclusive at both bounds', () {
      expect(
        BillValidators.dueDate(
          DateTime(today.year - BillValidators.maxYearsInPast, 8, 24),
          today: today,
        ),
        isNull,
      );
      expect(
        BillValidators.dueDate(
          DateTime(today.year + BillValidators.maxYearsInFuture, 8, 24),
          today: today,
        ),
        isNull,
      );
    });
  });

  group('optional fields', () {
    test('payee and notes may be empty', () {
      expect(BillValidators.payee(null), isNull);
      expect(BillValidators.payee(''), isNull);
      expect(BillValidators.notes(null), isNull);
      expect(BillValidators.notes(''), isNull);
    });

    test('but respect their limits', () {
      expect(
        BillValidators.payee('a' * (BillValidators.maxPayeeLength + 1)),
        isNotNull,
      );
      expect(
        BillValidators.notes('a' * (BillValidators.maxNotesLength + 1)),
        isNotNull,
      );
    });
  });

  group('isComplete', () {
    test('agrees with the individual validators', () {
      expect(
        BillValidators.isComplete(
          name: 'Meralco',
          amount: '1250.50',
          dueOn: today,
          today: today,
        ),
        isTrue,
      );
    });

    test('is false when any single field fails', () {
      // One case per field, so a validator dropped from isComplete shows up here
      // rather than as a form that submits invalid data.
      expect(
        BillValidators.isComplete(
          name: '',
          amount: '1250.50',
          dueOn: today,
          today: today,
        ),
        isFalse,
      );
      expect(
        BillValidators.isComplete(
          name: 'Meralco',
          amount: '0',
          dueOn: today,
          today: today,
        ),
        isFalse,
      );
      expect(
        BillValidators.isComplete(
          name: 'Meralco',
          amount: '1250.50',
          dueOn: null,
          today: today,
        ),
        isFalse,
      );
      expect(
        BillValidators.isComplete(
          name: 'Meralco',
          amount: '1250.50',
          dueOn: today,
          today: today,
          payee: 'a' * (BillValidators.maxPayeeLength + 1),
        ),
        isFalse,
      );
      expect(
        BillValidators.isComplete(
          name: 'Meralco',
          amount: '1250.50',
          dueOn: today,
          today: today,
          notes: 'a' * (BillValidators.maxNotesLength + 1),
        ),
        isFalse,
      );
    });
  });
}
