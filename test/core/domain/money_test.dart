import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';

/// Money is the type every amount in the app passes through, so it gets the
/// thorough treatment — and parsing especially, because that is where exactness
/// is usually lost.
void main() {
  group('parsing', () {
    test('reads plain and decimal amounts', () {
      expect(Money.tryParse('2450.50'), const Money.php(245050));
      expect(Money.tryParse('2450'), const Money.php(245000));
      expect(Money.tryParse('0.99'), const Money.php(99));
      expect(Money.tryParse('0'), const Money.php(0));
    });

    test('right-pads a single decimal', () {
      // '5' after the point means fifty centavos, not five.
      expect(Money.tryParse('12.5'), const Money.php(1250));
    });

    test('tolerates grouping, spaces and surrounding whitespace', () {
      expect(Money.tryParse(' 2,450.50 '), const Money.php(245050));
      expect(Money.tryParse('1,234,567'), const Money.php(123456700));
    });

    test('accepts a bare decimal point form', () {
      expect(Money.tryParse('.75'), const Money.php(75));
    });

    test('is exact where a double would not be', () {
      // double.parse('10.10') * 100 is 1009.9999999999999, which truncates to
      // 1009 — a centavo lost on an amount the user typed themselves.
      expect(Money.tryParse('10.10'), const Money.php(1010));
      expect(Money.tryParse('0.07'), const Money.php(7));
      expect(Money.tryParse('1.15'), const Money.php(115));
      expect(Money.tryParse('8.20'), const Money.php(820));
    });

    test('refuses what is not an amount', () {
      for (final String input in <String>[
        '',
        '   ',
        'abc',
        '12.345',
        '1.2.3',
        r'12$',
        '--5',
        '.',
      ]) {
        expect(
          Money.tryParse(input),
          isNull,
          reason: '"$input" should not parse',
        );
      }
    });

    test('handles a negative amount', () {
      expect(Money.tryParse('-12.50'), const Money.php(-1250));
    });

    test('carries the currency it was told', () {
      expect(
        Money.tryParse('9.99', currency: 'USD'),
        const Money(minorUnits: 999, currency: 'USD'),
      );
    });
  });

  group('arithmetic', () {
    test('adds and subtracts exactly', () {
      expect(const Money.php(1010) + const Money.php(7), const Money.php(1017));
      expect(
        const Money.php(245050) - const Money.php(50000),
        const Money.php(195050),
      );
    });

    test('sums a list of awkward amounts without drift', () {
      // The classic float failure: 0.1 ten times is not 1.0.
      Money total = const Money.zero('PHP');
      for (int i = 0; i < 10; i++) {
        total += const Money.php(10);
      }

      expect(total, const Money.php(100));
    });

    test('compares', () {
      expect(const Money.php(100) < const Money.php(200), isTrue);
      expect(const Money.php(200) >= const Money.php(200), isTrue);
      expect(const Money.php(300) > const Money.php(200), isTrue);
    });

    test('clamps a negative to zero', () {
      // "How much is still owed" on an overpaid bill is nothing, not a negative.
      expect(const Money.php(-500).clampToZero(), const Money.php(0));
      expect(const Money.php(500).clampToZero(), const Money.php(500));
    });
  });

  group('formatting', () {
    test('shows two decimals and grouping', () {
      expect(
        const Money.php(245050).format(locale: 'en_PH'),
        contains('2,450.50'),
      );
      expect(const Money.php(0).format(locale: 'en_PH'), contains('0.00'));
    });

    test('uses the currency it holds, not a hard-coded symbol', () {
      // A USD subscription showing a peso sign is worse than no symbol at all.
      final String usd = const Money(
        minorUnits: 999,
        currency: 'USD',
      ).format(locale: 'en_US');

      expect(usd, contains('9.99'));
      expect(usd, isNot(contains('₱')));
    });

    test('formatBare drops the symbol', () {
      final String bare = const Money.php(245050).formatBare(locale: 'en_PH');

      expect(bare, '2,450.50');
    });

    test('round-trips through parse', () {
      for (final int minor in <int>[0, 7, 99, 100, 1010, 245050, 123456789]) {
        final Money original = Money.php(minor);
        final Money? reparsed = Money.tryParse(
          original.formatBare(locale: 'en_US'),
        );

        expect(reparsed, original, reason: 'failed for $minor');
      }
    });
  });

  group('equality', () {
    test('two amounts of the same currency and value are equal', () {
      expect(const Money.php(100), const Money.php(100));
      expect(const Money.php(100).hashCode, const Money.php(100).hashCode);
    });

    test('the same number in different currencies is not', () {
      expect(
        const Money(minorUnits: 100, currency: 'PHP'),
        isNot(const Money(minorUnits: 100, currency: 'USD')),
      );
    });
  });
}
