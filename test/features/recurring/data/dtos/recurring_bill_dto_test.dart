import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/data/dtos/recurring_bill_dto.dart';
import 'package:paypaw/features/recurring/domain/entities/new_recurring_bill.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';

/// The mapper between a `public.recurring_bills` row and [RecurringBill].
///
/// Seven flat columns collapse into one [Recurrence] and back, and the column
/// names have to match `supabase/migrations/0005_recurring_bills.sql` exactly —
/// a mismatch is a runtime insert failure, not a compile error.
void main() {
  Map<String, dynamic> row({
    Object? frequency = 'monthly',
    Object? intervalCount = 1,
    Object? dayOfMonth = 15,
    Object? weekday,
    Object? monthOfYear,
    Object? endsOn,
    Object? isActive = true,
    Object? kind = 'bill',
    Object? amountMinor = 149900,
  }) => <String, dynamic>{
    'id': 'rec-1',
    'user_id': 'user-1',
    'category_id': 'cat-internet',
    'kind': kind,
    'name': 'Converge',
    'payee': 'Converge ICT',
    'amount_minor': amountMinor,
    'currency': 'PHP',
    'frequency': frequency,
    'interval_count': intervalCount,
    'day_of_month': dayOfMonth,
    'weekday': weekday,
    'month_of_year': monthOfYear,
    'starts_on': '2026-01-05',
    'ends_on': endsOn,
    'next_due_on': '2026-01-15',
    'is_active': isActive,
    'created_at': '2026-01-02T02:15:00Z',
    'updated_at': '2026-01-02T02:15:00Z',
  };

  group('toEntity', () {
    test('reads a row', () {
      final RecurringBill bill = RecurringBillDto.toEntity(row());

      expect(bill.id, 'rec-1');
      expect(bill.name, 'Converge');
      expect(bill.payee, 'Converge ICT');
      expect(bill.categoryId, 'cat-internet');
      expect(bill.kind, RecurringBillKind.bill);
      expect(bill.amount, const Money.php(149900));
      expect(bill.isActive, isTrue);
      expect(bill.nextDueOn, DateTime(2026, 1, 15));
    });

    test('collapses the seven schedule columns into one recurrence', () {
      final Recurrence rule = RecurringBillDto.toEntity(
        row(frequency: 'quarterly', intervalCount: 2, dayOfMonth: -1),
      ).recurrence;

      expect(rule.frequency, RecurrenceFrequency.quarterly);
      expect(rule.intervalCount, 2);
      expect(rule.dayOfMonth, Recurrence.lastDayOfMonth);
      expect(rule.startsOn, DateTime(2026, 1, 5));
      expect(rule.endsOn, isNull);
    });

    test('a weekly row has a weekday and no day of month', () {
      final Recurrence rule = RecurringBillDto.toEntity(
        row(frequency: 'weekly', dayOfMonth: null, weekday: 3),
      ).recurrence;

      expect(rule.weekday, 3);
      expect(rule.dayOfMonth, isNull);
      expect(rule.isValid, isTrue);
    });

    test('a null weekday on a monthly rule is correct, not a bad row', () {
      // The recurrence columns are nullable ints, so requireInt is the wrong tool
      // for them.
      expect(RecurringBillDto.toEntity(row()).recurrence.weekday, isNull);
    });

    test('reads an end date when there is one', () {
      final Recurrence rule = RecurringBillDto.toEntity(
        row(endsOn: '2026-12-31'),
      ).recurrence;

      expect(rule.endsOn, DateTime(2026, 12, 31));
    });

    test('dates are parsed as local days, not through DateTime.parse', () {
      // starts_on and next_due_on are SQL `date`s. Parsing them as instants would
      // make a date-only value sensitive to the device's timezone, and a due date
      // is the same day everywhere.
      final RecurringBill bill = RecurringBillDto.toEntity(row());

      expect(bill.nextDueOn.hour, 0);
      expect(bill.nextDueOn.isUtc, isFalse);
      expect(bill.recurrence.startsOn, DateTime(2026, 1, 5));
    });

    test('a subscription reads as one', () {
      expect(
        RecurringBillDto.toEntity(row(kind: 'subscription')).kind,
        RecurringBillKind.subscription,
      );
    });

    test('an unknown kind falls back to bill rather than null', () {
      // Safe to default: the column is not-null with a default of 'bill', and a
      // template the app cannot classify still has to appear in a list.
      expect(
        RecurringBillDto.toEntity(row(kind: 'something-new')).kind,
        RecurringBillKind.bill,
      );
    });

    test('a missing is_active reads as active, not paused', () {
      // Guessing "paused" would silently stop generating bills the user is still
      // expecting.
      expect(RecurringBillDto.toEntity(row(isActive: null)).isActive, isTrue);
    });

    test('an unknown frequency throws instead of degrading', () {
      // Unlike a bill's status, a schedule the app cannot read is not something to
      // render as "unknown" and move on from: every date it would produce would be
      // wrong, and it is the thing generation acts on.
      expect(
        () => RecurringBillDto.toEntity(row(frequency: 'fortnightly')),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('recurring_bills.frequency'),
          ),
        ),
      );
    });

    test('an unreadable amount throws rather than reading as zero', () {
      expect(
        () => RecurringBillDto.toEntity(row(amountMinor: null)),
        throwsFormatException,
      );
    });

    test('a bigint sent as a string still reads as a number', () {
      expect(
        RecurringBillDto.toEntity(row(amountMinor: '149900')).amount.minorUnits,
        149900,
      );
    });
  });

  group('toInsert', () {
    final NewRecurringBill draft = NewRecurringBill(
      name: '  Converge  ',
      amount: const Money.php(149900),
      payee: '  Converge ICT  ',
      categoryId: 'cat-internet',
      recurrence: Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 5),
      ),
    );

    test('takes user_id from the caller, not the draft', () {
      // The draft deliberately has no owner, so no call site can pass the wrong
      // one.
      final Map<String, dynamic> values = RecurringBillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['user_id'], 'user-1');
    });

    test('sends next_due_on as the rule first occurrence', () {
      // The column is not-null with no default, and the only correct value at
      // creation is the rule's own first occurrence — otherwise the bookmark is a
      // date generation can never reach.
      expect(
        RecurringBillDto.toInsert(draft, userId: 'user-1')['next_due_on'],
        '2026-01-15',
      );
    });

    test('formats dates as YYYY-MM-DD, never as instants', () {
      // toIso8601String would append a time and a timezone, and make the value
      // depend on where the device is.
      final Map<String, dynamic> values = RecurringBillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['starts_on'], '2026-01-05');
      expect(values['next_due_on'], '2026-01-15');
    });

    test('trims the name and the payee', () {
      final Map<String, dynamic> values = RecurringBillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['name'], 'Converge');
      expect(values['payee'], 'Converge ICT');
    });

    test('omits the database-owned columns', () {
      final Map<String, dynamic> values = RecurringBillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values.containsKey('id'), isFalse);
      expect(values.containsKey('created_at'), isFalse);
      expect(values.containsKey('updated_at'), isFalse);
    });

    test('refuses a draft whose rule never comes due', () {
      // Only reachable if a caller skipped validate(). Failing here beats sending
      // a null into a not-null column and reading the Postgres error.
      final NewRecurringBill impossible = NewRecurringBill(
        name: 'Nothing',
        amount: const Money.php(100),
        recurrence: Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 15,
          startsOn: DateTime(2026, 1, 2),
          endsOn: DateTime(2026, 1, 10),
        ),
      );

      expect(impossible.isValid, isFalse);
      expect(
        () => RecurringBillDto.toInsert(impossible, userId: 'user-1'),
        throwsStateError,
      );
    });
  });

  group('the schedule columns', () {
    Map<String, dynamic> insertFor(Recurrence rule) =>
        RecurringBillDto.toInsert(
          NewRecurringBill(
            name: 'Test',
            amount: const Money.php(100),
            recurrence: rule,
          ),
          userId: 'user-1',
        );

    test('a weekly rule nulls day_of_month and month_of_year', () {
      // Sent as null rather than left out. Omitting them would leave a stale
      // month_of_year behind on a rule changed from yearly to weekly, and the
      // recurrence-shape constraint does not catch that — it checks that the
      // needed fields are present, not that the unneeded ones are absent.
      final Map<String, dynamic> values = insertFor(
        Recurrence(
          frequency: RecurrenceFrequency.weekly,
          weekday: 2,
          startsOn: DateTime(2026, 1, 5),
        ),
      );

      expect(values['weekday'], 2);
      expect(values.containsKey('day_of_month'), isTrue);
      expect(values['day_of_month'], isNull);
      expect(values['month_of_year'], isNull);
    });

    test('a monthly rule nulls weekday and month_of_year', () {
      final Map<String, dynamic> values = insertFor(
        Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 15,
          startsOn: DateTime(2026, 1, 5),
        ),
      );

      expect(values['day_of_month'], 15);
      expect(values['weekday'], isNull);
      expect(values['month_of_year'], isNull);
    });

    test('a yearly rule keeps its month', () {
      final Map<String, dynamic> values = insertFor(
        Recurrence(
          frequency: RecurrenceFrequency.yearly,
          dayOfMonth: 15,
          monthOfYear: 3,
          startsOn: DateTime(2026, 1, 5),
        ),
      );

      expect(values['month_of_year'], 3);
      expect(values['weekday'], isNull);
    });

    test('the last-day sentinel goes over the wire as -1', () {
      final Map<String, dynamic> values = insertFor(
        Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: Recurrence.lastDayOfMonth,
          startsOn: DateTime(2026, 1, 5),
        ),
      );

      expect(values['day_of_month'], -1);
    });

    test('an open-ended rule sends a null end date', () {
      expect(
        insertFor(
          Recurrence(
            frequency: RecurrenceFrequency.monthly,
            dayOfMonth: 15,
            startsOn: DateTime(2026, 1, 5),
          ),
        )['ends_on'],
        isNull,
      );
    });
  });

  group('toUpdate', () {
    final RecurringBill bill = RecurringBillDto.toEntity(row());

    test('excludes ownership and the database-owned timestamps', () {
      final Map<String, dynamic> values = RecurringBillDto.toUpdate(bill);

      expect(values.containsKey('user_id'), isFalse);
      expect(values.containsKey('created_at'), isFalse);
      expect(values.containsKey('updated_at'), isFalse);
    });

    test(
      'includes next_due_on, because advancing the bookmark is an update',
      () {
        expect(RecurringBillDto.toUpdate(bill)['next_due_on'], '2026-01-15');
        expect(
          RecurringBillDto.toUpdate(
            bill.copyWith(nextDueOn: DateTime(2026, 2, 15)),
          )['next_due_on'],
          '2026-02-15',
        );
      },
    );

    test('includes is_active, because pausing is an update', () {
      expect(
        RecurringBillDto.toUpdate(bill.copyWith(isActive: false))['is_active'],
        isFalse,
      );
    });
  });

  group('a round trip', () {
    test('survives every frequency', () {
      final List<Recurrence> rules = <Recurrence>[
        Recurrence(
          frequency: RecurrenceFrequency.weekly,
          weekday: 5,
          intervalCount: 2,
          startsOn: DateTime(2026, 1, 5),
        ),
        Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: Recurrence.lastDayOfMonth,
          startsOn: DateTime(2026, 1, 5),
        ),
        Recurrence(
          frequency: RecurrenceFrequency.quarterly,
          dayOfMonth: 10,
          startsOn: DateTime(2026, 1, 5),
          endsOn: DateTime(2027, 6, 30),
        ),
        Recurrence(
          frequency: RecurrenceFrequency.yearly,
          dayOfMonth: 1,
          monthOfYear: 4,
          intervalCount: 3,
          startsOn: DateTime(2026, 1, 5),
        ),
      ];

      for (final Recurrence rule in rules) {
        // Build the row the way the insert would, then read it back. Catches a
        // column written under one name and read under another, which is the
        // failure a hand-written mapper actually has.
        final Map<String, dynamic> written = RecurringBillDto.toInsert(
          NewRecurringBill(
            name: 'Test',
            amount: const Money.php(100),
            recurrence: rule,
          ),
          userId: 'user-1',
        );

        final RecurringBill read = RecurringBillDto.toEntity(<String, dynamic>{
          ...written,
          'id': 'rec-1',
          'created_at': '2026-01-02T02:15:00Z',
          'updated_at': '2026-01-02T02:15:00Z',
        });

        expect(read.recurrence, rule, reason: rule.describe());
      }
    });
  });

  test('selectColumns names every column the mapper reads', () {
    for (final String column in <String>[
      'id',
      'user_id',
      'category_id',
      'kind',
      'name',
      'payee',
      'amount_minor',
      'currency',
      'frequency',
      'interval_count',
      'day_of_month',
      'weekday',
      'month_of_year',
      'starts_on',
      'ends_on',
      'next_due_on',
      'is_active',
      'created_at',
      'updated_at',
    ]) {
      expect(RecurringBillDto.selectColumns, contains(column));
    }
  });
}
