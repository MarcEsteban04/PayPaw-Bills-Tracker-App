import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';

/// The recurrence arithmetic.
///
/// Sprint 33 is the dedicated recurrence-testing sprint, but the month-boundary
/// cases are not something to write the arithmetic without: a schedule that
/// ratchets earlier every February is invisible for a year and permanent after
/// that. These are the cases that decide whether the design is right.
void main() {
  Recurrence monthly({
    int day = 15,
    int interval = 1,
    DateTime? from,
    DateTime? until,
  }) => Recurrence(
    frequency: RecurrenceFrequency.monthly,
    dayOfMonth: day,
    intervalCount: interval,
    startsOn: from ?? DateTime(2026, 1, 5),
    endsOn: until,
  );

  Recurrence weekly({
    int on = DateTime.monday,
    int interval = 1,
    DateTime? from,
  }) => Recurrence(
    frequency: RecurrenceFrequency.weekly,
    weekday: on,
    intervalCount: interval,
    startsOn: from ?? DateTime(2026, 1, 5),
  );

  group('monthly', () {
    test('steps a month at a time', () {
      final Recurrence rule = monthly();

      expect(rule.firstOccurrence, DateTime(2026, 1, 15));
      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 15)),
        DateTime(2026, 2, 15),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 15)),
        DateTime(2026, 3, 15),
      );
    });

    test('starts this month when the day has not passed', () {
      expect(
        monthly(day: 20, from: DateTime(2026, 1, 5)).firstOccurrence,
        DateTime(2026, 1, 20),
      );
    });

    test('and next month when it has', () {
      expect(
        monthly(day: 3, from: DateTime(2026, 1, 5)).firstOccurrence,
        DateTime(2026, 2, 3),
      );
    });

    test('starts on the start date when they coincide', () {
      expect(
        monthly(day: 5, from: DateTime(2026, 1, 5)).firstOccurrence,
        DateTime(2026, 1, 5),
      );
    });

    test('an interval skips months', () {
      final Recurrence rule = monthly(interval: 3);

      expect(rule.firstOccurrence, DateTime(2026, 1, 15));
      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 15)),
        DateTime(2026, 4, 15),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 4, 15)),
        DateTime(2026, 7, 15),
      );
    });
  });

  group('month boundaries', () {
    test('the 31st clamps in short months and comes back in long ones', () {
      // The case the whole design exists for. Stepping from the previous
      // occurrence would give 28 March here, and every February would ratchet
      // the schedule earlier until it stuck on the 28th forever.
      final Recurrence rule = monthly(day: 31, from: DateTime(2026, 1, 2));

      expect(rule.firstOccurrence, DateTime(2026, 1, 31));
      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 28)),
        DateTime(2026, 3, 31),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 3, 31)),
        DateTime(2026, 4, 30),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 4, 30)),
        DateTime(2026, 5, 31),
      );
    });

    test('the 30th clamps only in February', () {
      final Recurrence rule = monthly(day: 30, from: DateTime(2026, 1, 2));

      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 30)),
        DateTime(2026, 2, 28),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 28)),
        DateTime(2026, 3, 30),
      );
    });

    test('a leap February keeps the 29th', () {
      // 2028 is a leap year.
      final Recurrence rule = monthly(day: 31, from: DateTime(2028, 1, 2));

      expect(
        rule.occurrenceAfter(DateTime(2028, 1, 31)),
        DateTime(2028, 2, 29),
      );
    });

    test('and a century non-leap year does not', () {
      // 2100 is divisible by 4 and by 100 but not by 400, so it is not a leap
      // year. Left to DateTime rather than reimplemented, which is the point.
      final Recurrence rule = monthly(day: 31, from: DateTime(2100, 1, 2));

      expect(
        rule.occurrenceAfter(DateTime(2100, 1, 31)),
        DateTime(2100, 2, 28),
      );
    });

    test('the last-day sentinel follows each month length', () {
      // -1 rather than storing 31 and hoping.
      final Recurrence rule = monthly(
        day: Recurrence.lastDayOfMonth,
        from: DateTime(2026, 1, 2),
      );

      expect(rule.firstOccurrence, DateTime(2026, 1, 31));
      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 28)),
        DateTime(2026, 3, 31),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 3, 31)),
        DateTime(2026, 4, 30),
      );
    });

    test('a year rolls over', () {
      final Recurrence rule = monthly(from: DateTime(2026, 12, 2));

      expect(rule.firstOccurrence, DateTime(2026, 12, 15));
      expect(
        rule.occurrenceAfter(DateTime(2026, 12, 15)),
        DateTime(2027, 1, 15),
      );
    });
  });

  group('weekly', () {
    test('lands on its weekday', () {
      // 5 January 2026 is a Monday.
      final Recurrence rule = weekly();

      expect(rule.firstOccurrence, DateTime(2026, 1, 5));
      expect(rule.occurrenceAfter(DateTime(2026, 1, 5)), DateTime(2026, 1, 12));
    });

    test('advances to the weekday when the start date is not one', () {
      // Starting on Monday the 5th, asking for Thursdays.
      final Recurrence rule = weekly(on: DateTime.thursday);

      expect(rule.firstOccurrence, DateTime(2026, 1, 8));
    });

    test(
      'an interval of 2 is bi-weekly, which needs no wire value of its own',
      () {
        final Recurrence rule = weekly(interval: 2);

        expect(rule.firstOccurrence, DateTime(2026, 1, 5));
        expect(
          rule.occurrenceAfter(DateTime(2026, 1, 5)),
          DateTime(2026, 1, 19),
        );
        expect(
          rule.occurrenceAfter(DateTime(2026, 1, 19)),
          DateTime(2026, 2, 2),
        );
      },
    );

    test('a date between occurrences returns the next one, not the last', () {
      final Recurrence rule = weekly(interval: 2);

      expect(
        rule.occurrenceAfter(DateTime(2026, 1, 10)),
        DateTime(2026, 1, 19),
      );
    });

    test('crosses a month and a year without drifting', () {
      final Recurrence rule = weekly(
        on: DateTime.wednesday,
        from: DateTime(2026, 12, 23),
      );

      expect(rule.firstOccurrence, DateTime(2026, 12, 23));
      expect(
        rule.occurrenceAfter(DateTime(2026, 12, 23)),
        DateTime(2026, 12, 30),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 12, 30)),
        DateTime(2027, 1, 6),
      );
    });
  });

  group('quarterly and yearly', () {
    test('quarterly steps three months from where it started', () {
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.quarterly,
        dayOfMonth: 10,
        startsOn: DateTime(2026, 2, 2),
      );

      expect(rule.firstOccurrence, DateTime(2026, 2, 10));
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 10)),
        DateTime(2026, 5, 10),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 5, 10)),
        DateTime(2026, 8, 10),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 8, 10)),
        DateTime(2026, 11, 10),
      );
      expect(
        rule.occurrenceAfter(DateTime(2026, 11, 10)),
        DateTime(2027, 2, 10),
      );
    });

    test('yearly takes its month from the rule, not from the start date', () {
      // Starting in January, due in March. The first occurrence is March of the
      // same year — not January, and not next March.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.yearly,
        dayOfMonth: 15,
        monthOfYear: 3,
        startsOn: DateTime(2026, 1, 5),
      );

      expect(rule.firstOccurrence, DateTime(2026, 3, 15));
      expect(
        rule.occurrenceAfter(DateTime(2026, 3, 15)),
        DateTime(2027, 3, 15),
      );
    });

    test('and rolls to next year when its month has already passed', () {
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.yearly,
        dayOfMonth: 15,
        monthOfYear: 3,
        startsOn: DateTime(2026, 6, 2),
      );

      expect(rule.firstOccurrence, DateTime(2027, 3, 15));
    });

    test('a yearly 29 February falls back except in leap years', () {
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.yearly,
        dayOfMonth: 29,
        monthOfYear: 2,
        startsOn: DateTime(2026, 1, 2),
      );

      expect(rule.firstOccurrence, DateTime(2026, 2, 28));
      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 28)),
        DateTime(2027, 2, 28),
      );
      // 2028 is a leap year, and the rule remembers it asked for the 29th.
      expect(
        rule.occurrenceAfter(DateTime(2027, 2, 28)),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('the end date', () {
    test('stops the schedule', () {
      final Recurrence rule = monthly(until: DateTime(2026, 3, 20));

      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 15)),
        DateTime(2026, 3, 15),
      );
      expect(rule.occurrenceAfter(DateTime(2026, 3, 15)), isNull);
    });

    test('includes an occurrence landing exactly on it', () {
      final Recurrence rule = monthly(until: DateTime(2026, 3, 15));

      expect(
        rule.occurrenceAfter(DateTime(2026, 2, 15)),
        DateTime(2026, 3, 15),
      );
    });

    test('a rule ending before its first occurrence produces nothing', () {
      // A real state: "monthly on the 15th, ending the 10th". It has to answer
      // null rather than a date outside its own range.
      final Recurrence rule = monthly(
        from: DateTime(2026, 1, 2),
        until: DateTime(2026, 1, 10),
      );

      expect(rule.firstOccurrence, isNull);
      expect(rule.occurrencesFrom(DateTime(2026, 1, 2)), isEmpty);
    });
  });

  group('occurrencesFrom', () {
    test('counts the date it is given', () {
      // `occurrenceAfter` is exclusive; a caller asking "from today" means today
      // counts if it is a due date.
      final Recurrence rule = monthly();

      expect(rule.occurrencesFrom(DateTime(2026, 1, 15), limit: 2), <DateTime>[
        DateTime(2026, 1, 15),
        DateTime(2026, 2, 15),
      ]);
    });

    test('gives the next few', () {
      expect(
        monthly().occurrencesFrom(DateTime(2026, 1, 2), limit: 4),
        <DateTime>[
          DateTime(2026, 1, 15),
          DateTime(2026, 2, 15),
          DateTime(2026, 3, 15),
          DateTime(2026, 4, 15),
        ],
      );
    });

    test(
      'stops early rather than padding, so a finite rule can be told apart',
      () {
        final Recurrence rule = monthly(until: DateTime(2026, 3, 31));

        expect(
          rule.occurrencesFrom(DateTime(2026, 1, 2), limit: 10),
          hasLength(3),
        );
      },
    );
  });

  group('validation', () {
    test('mirrors the recurrence-shape constraint', () {
      // A "monthly" template with no day of month is storable without this, and
      // the bug surfaces much later as an occurrence that never generates.
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.monthly,
          startsOn: DateTime(2026, 1, 2),
        ).validate(),
        'Choose which day of the month.',
      );
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.weekly,
          startsOn: DateTime(2026, 1, 2),
        ).validate(),
        'Choose which day of the week.',
      );
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.yearly,
          dayOfMonth: 15,
          startsOn: DateTime(2026, 1, 2),
        ).validate(),
        'Choose which month.',
      );
    });

    test('bounds the interval the way the column does', () {
      expect(monthly().isValid, isTrue);
      expect(monthly(interval: 60).isValid, isTrue);
      expect(monthly(interval: 0).isValid, isFalse);
      expect(monthly(interval: 61).isValid, isFalse);
    });

    test(
      'rejects a day of month outside the range, but allows the sentinel',
      () {
        expect(monthly(day: 0).isValid, isFalse);
        expect(monthly(day: 32).isValid, isFalse);
        expect(monthly(day: Recurrence.lastDayOfMonth).isValid, isTrue);
      },
    );

    test('rejects an end date before the start', () {
      expect(
        monthly(
          from: DateTime(2026, 6, 2),
          until: DateTime(2026, 5, 2),
        ).validate(),
        'The end date cannot be before the start date.',
      );
    });

    test('accepts an end date equal to the start', () {
      expect(
        monthly(
          from: DateTime(2026, 6, 2),
          until: DateTime(2026, 6, 2),
        ).isValid,
        isTrue,
      );
    });
  });

  group('dates, not moments', () {
    test('a start date with a time on it is normalised', () {
      // A due date is the same day in every zone. Keeping the time would make
      // every comparison sensitive to when the row happened to be created.
      final Recurrence rule = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: DateTime(2026, 1, 5, 23, 45),
      );

      expect(rule.startsOn, DateTime(2026, 1, 5));
      expect(rule.firstOccurrence, DateTime(2026, 1, 15));
    });

    test('every occurrence is at midnight', () {
      for (final DateTime date in monthly().occurrencesFrom(
        DateTime(2026, 1, 2),
        limit: 2,
      )) {
        expect(date.hour, 0);
        expect(date.minute, 0);
      }
    });
  });

  group('describe', () {
    test('names the unit and the day', () {
      expect(monthly().describe(), 'Every month on the 15th');
      expect(monthly(interval: 2).describe(), 'Every 2 months on the 15th');
      expect(
        monthly(day: Recurrence.lastDayOfMonth).describe(),
        'Every month on the last day',
      );
    });

    test('gets the awkward ordinals right', () {
      // 11th, 12th and 13th are the ones the naive rule turns into 11st, 12nd,
      // 13rd.
      expect(monthly(day: 1).describe(), endsWith('the 1st'));
      expect(monthly(day: 2).describe(), endsWith('the 2nd'));
      expect(monthly(day: 3).describe(), endsWith('the 3rd'));
      expect(monthly(day: 11).describe(), endsWith('the 11th'));
      expect(monthly(day: 12).describe(), endsWith('the 12th'));
      expect(monthly(day: 13).describe(), endsWith('the 13th'));
      expect(monthly(day: 21).describe(), endsWith('the 21st'));
    });

    test('names the weekday, using the ISO numbering DateTime uses', () {
      // Off-by-one here shifts every occurrence by a fixed number of days, which
      // looks like a timezone bug and is not one.
      expect(weekly().describe(), 'Every week on Monday');
      expect(weekly(on: DateTime.sunday).describe(), 'Every week on Sunday');
      expect(
        weekly(on: DateTime.friday, interval: 2).describe(),
        'Every 2 weeks on Friday',
      );
    });

    test('names the month for a yearly rule', () {
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.yearly,
          dayOfMonth: 15,
          monthOfYear: 3,
          startsOn: DateTime(2026, 1, 2),
        ).describe(),
        'Every year on 15th of March',
      );
    });

    test('and says quarter, not 3 months', () {
      expect(
        Recurrence(
          frequency: RecurrenceFrequency.quarterly,
          dayOfMonth: 10,
          startsOn: DateTime(2026, 1, 2),
        ).describe(),
        'Every quarter on the 10th',
      );
    });
  });

  group('the frequency enum', () {
    test('wire values match the check constraint', () {
      expect(
        RecurrenceFrequency.tryParse('weekly'),
        RecurrenceFrequency.weekly,
      );
      expect(
        RecurrenceFrequency.tryParse('monthly'),
        RecurrenceFrequency.monthly,
      );
      expect(
        RecurrenceFrequency.tryParse('quarterly'),
        RecurrenceFrequency.quarterly,
      );
      expect(
        RecurrenceFrequency.tryParse('yearly'),
        RecurrenceFrequency.yearly,
      );
      expect(RecurrenceFrequency.values, hasLength(4));
    });

    test('bi-weekly and custom are not wire values', () {
      // They are intervals, not frequencies. Adding them would be two more ways
      // to say what interval_count already says.
      expect(RecurrenceFrequency.tryParse('biweekly'), isNull);
      expect(RecurrenceFrequency.tryParse('custom'), isNull);
      expect(RecurrenceFrequency.tryParse(null), isNull);
    });

    test(
      'weekly has no month step, so a caller cannot silently mis-handle it',
      () {
        expect(RecurrenceFrequency.weekly.monthsPerStep, isNull);
        expect(RecurrenceFrequency.monthly.monthsPerStep, 1);
        expect(RecurrenceFrequency.quarterly.monthsPerStep, 3);
        expect(RecurrenceFrequency.yearly.monthsPerStep, 12);
      },
    );
  });

  group('clearing', () {
    test('drops the fields a changed frequency no longer needs', () {
      // Switching yearly to weekly has to lose its month of year, and a copyWith
      // where null means "leave it alone" cannot say so.
      final Recurrence yearly = Recurrence(
        frequency: RecurrenceFrequency.yearly,
        dayOfMonth: 15,
        monthOfYear: 3,
        startsOn: DateTime(2026, 1, 2),
      );

      final Recurrence asWeekly = yearly
          .copyWith(frequency: RecurrenceFrequency.weekly, weekday: 1)
          .clearing(dayOfMonth: true, monthOfYear: true);

      expect(asWeekly.monthOfYear, isNull);
      expect(asWeekly.dayOfMonth, isNull);
      expect(asWeekly.isValid, isTrue);
    });
  });
}
