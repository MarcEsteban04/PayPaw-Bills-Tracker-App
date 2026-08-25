import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/calendar/domain/entities/calendar_month.dart';

/// The grid a month is drawn as.
///
/// Pure arithmetic, and the kind that is wrong by exactly one day for exactly
/// one month of the year — which is a bug nobody finds in review and everybody
/// finds in March.
void main() {
  group('the grid', () {
    test('always has six rows of seven, whatever the month', () {
      // A month needs five rows or six depending on the weekday it starts on. A
      // grid that changed height would jump the page on every step forward.
      for (int month = 1; month <= 12; month++) {
        final CalendarMonth grid = CalendarMonth(2026, month);

        expect(grid.days, hasLength(42), reason: 'month $month');
        expect(grid.weeks, hasLength(6), reason: 'month $month');
        expect(grid.weeks.every((List<DateTime> w) => w.length == 7), isTrue);
      }
    });

    test('starts on the chosen weekday', () {
      expect(CalendarMonth(2026, 9).days.first.weekday, DateTime.sunday);
      expect(
        CalendarMonth(
          2026,
          9,
          firstWeekday: DateTime.monday,
        ).days.first.weekday,
        DateTime.monday,
      );
    });

    test('leads with the days that finish the previous month', () {
      // 1 September 2026 is a Tuesday, so a Sunday-start grid opens with the
      // 30th and the 31st of August.
      final CalendarMonth september = CalendarMonth(2026, 9);

      expect(september.days.first, DateTime(2026, 8, 30));
      expect(september.days[1], DateTime(2026, 8, 31));
      // The first of the month: DateTime defaults the day, and the analyzer
      // would rather it were not spelled out.
      expect(september.days[2], DateTime(2026, 9));
    });

    test('and needs no lead at all when the first falls on the start day', () {
      // 1 March 2026 is a Sunday.
      expect(CalendarMonth(2026, 3).days.first, DateTime(2026, 3));
    });

    test('runs on into the month that follows', () {
      expect(CalendarMonth(2026, 9).days.last, DateTime(2026, 10, 10));
    });

    test('is contiguous — every cell is the day after the one before', () {
      // The property the whole type exists to guarantee, checked rather than
      // spot-asserted. A grid with a repeated or skipped date is the classic
      // result of stepping by Duration across a DST boundary.
      final CalendarMonth grid = CalendarMonth(2026, 3);

      for (int i = 1; i < grid.days.length; i++) {
        final DateTime previous = grid.days[i - 1];

        expect(
          grid.days[i],
          DateTime(previous.year, previous.month, previous.day + 1),
          reason: 'cell $i',
        );
      }
    });

    test('and every cell is midnight, so it can key a lookup', () {
      expect(
        CalendarMonth(2026, 9).days.every((DateTime d) => d.hour == 0),
        isTrue,
      );
    });
  });

  group('February', () {
    test('a leap year runs to the 29th', () {
      final List<DateTime> february = CalendarMonth(
        2028,
        2,
      ).days.where((DateTime d) => d.month == 2).toList();

      expect(february.last.day, 29);
    });

    test('and a common year to the 28th', () {
      final List<DateTime> february = CalendarMonth(
        2026,
        2,
      ).days.where((DateTime d) => d.month == 2).toList();

      expect(february.last.day, 28);
    });
  });

  group('the column headings', () {
    test('run from the start day round to the day before it', () {
      expect(CalendarMonth(2026, 9).weekdays, <int>[
        DateTime.sunday,
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      ]);
    });

    test('and follow the start day when it moves', () {
      expect(
        CalendarMonth(2026, 9, firstWeekday: DateTime.monday).weekdays.last,
        DateTime.sunday,
      );
    });

    test('they line up with the cells beneath them', () {
      // The failure this prevents: labels and columns drifting apart, which
      // reads as a calendar where the dates are simply on the wrong days.
      final CalendarMonth grid = CalendarMonth(2026, 9);

      for (int column = 0; column < 7; column++) {
        expect(grid.weeks.first[column].weekday, grid.weekdays[column]);
      }
    });
  });

  group('stepping', () {
    test('forward and back a month', () {
      expect(CalendarMonth(2026, 9).next, CalendarMonth(2026, 10));
      expect(CalendarMonth(2026, 9).previous, CalendarMonth(2026, 8));
    });

    test('across a year boundary in both directions', () {
      expect(CalendarMonth(2026, 12).next, CalendarMonth(2027, 1));
      expect(CalendarMonth(2026, 1).previous, CalendarMonth(2025, 12));
    });

    test('keeps the start day', () {
      final CalendarMonth monday = CalendarMonth(
        2026,
        9,
        firstWeekday: DateTime.monday,
      );

      expect(monday.next.firstWeekday, DateTime.monday);
      expect(monday.previous.firstWeekday, DateTime.monday);
    });

    test('and the distance between two months is signed', () {
      // Which way a change animates cannot be answered by comparing dates.
      expect(CalendarMonth(2027, 1).monthsFrom(CalendarMonth(2026, 11)), 2);
      expect(CalendarMonth(2026, 11).monthsFrom(CalendarMonth(2027, 1)), -2);
      expect(CalendarMonth(2026, 9).monthsFrom(CalendarMonth(2026, 9)), 0);
    });
  });

  group('membership', () {
    test('a date in the month is in it, whatever time of day', () {
      expect(
        CalendarMonth(2026, 9).contains(DateTime(2026, 9, 30, 23, 59)),
        isTrue,
      );
    });

    test('and a leading or trailing cell is not', () {
      final CalendarMonth september = CalendarMonth(2026, 9);

      expect(september.contains(september.days.first), isFalse);
      expect(september.contains(september.days.last), isFalse);
    });

    test('the same month a year away is a different month', () {
      expect(CalendarMonth(2026, 9).contains(DateTime(2027, 9, 15)), isFalse);
    });
  });

  group('construction', () {
    test('a month past December is the next year', () {
      // [next] leans on this, and so does anything that does its own arithmetic.
      expect(CalendarMonth(2026, 13).month, 1);
      expect(CalendarMonth(2026, 13).year, 2027);
    });

    test('and one built from a date takes that date\'s month', () {
      expect(
        CalendarMonth.of(DateTime(2026, 9, 18, 14, 30)),
        CalendarMonth(2026, 9),
      );
    });

    test('two months are equal when they are the same month', () {
      expect(CalendarMonth(2026, 9), CalendarMonth(2026, 9));
      expect(CalendarMonth(2026, 9).hashCode, CalendarMonth(2026, 9).hashCode);
      expect(CalendarMonth(2026, 9), isNot(CalendarMonth(2026, 10)));
    });

    test('but not when they are laid out differently', () {
      // The grids differ, so the pages differ.
      expect(
        CalendarMonth(2026, 9),
        isNot(CalendarMonth(2026, 9, firstWeekday: DateTime.monday)),
      );
    });
  });

  test('dateOnly strips the clock, which is what makes lookups match', () {
    // A bill's due date arrives at midnight and the device clock does not.
    expect(
      CalendarMonth.dateOnly(DateTime(2026, 9, 18, 14, 30)),
      DateTime(2026, 9, 18),
    );
  });
}
