import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// An exact amount of money.
///
/// Holds **minor units** — centavos, not pesos — as an `int`, matching the
/// `*_minor` columns in the database. See `docs/database_schema.md` for why the
/// database stores it that way; the short version is that binary floating point
/// cannot represent 0.1, and a bills app that loses centavos is broken in the one
/// way its users notice.
///
/// This type exists so the unit cannot be got wrong. A bare `int` called `amount`
/// is one careless call away from meaning pesos, and the bug it produces is a
/// hundredfold error in someone's finances. `Money` makes the unit part of the
/// type, and gives formatting exactly one home.
///
/// ## The two-decimal assumption
///
/// [minorPerMajor] is 100, which is correct for PHP and USD — every currency
/// PayPaw expects. It is *not* universal: JPY has no minor unit and KWD has
/// three. Supporting those needs a per-currency exponent lookup, which is a
/// feature rather than a constant, and is not worth building before a user asks.
/// Until then this assumption is stated here rather than scattered implicitly
/// through the app.
@immutable
class Money implements Comparable<Money> {
  const Money({required this.minorUnits, required this.currency});

  /// Zero in [currency].
  const Money.zero(this.currency) : minorUnits = 0;

  /// Pesos, the common case.
  const Money.php(this.minorUnits) : currency = 'PHP';

  /// Minor units — centavos for PHP. Never pesos.
  final int minorUnits;

  /// ISO 4217 code, e.g. `PHP`.
  final String currency;

  /// Minor units in one major unit. See the class comment.
  static const int minorPerMajor = 100;

  /// Whether this is exactly zero.
  bool get isZero => minorUnits == 0;

  /// Whether this is greater than zero.
  bool get isPositive => minorUnits > 0;

  /// Parses user input such as `2450.50`, `2,450.5` or `2450`.
  ///
  /// Returns null for anything unparseable, so a caller can treat it as a
  /// validation failure rather than catching.
  ///
  /// Deliberately *not* `double.parse(...) * 100`. That route turns `10.10` into
  /// 1009.9999999999999 and then into 1009 centavos — a centavo lost, silently,
  /// on an amount a user typed themselves. This works on the digits instead and
  /// is exact.
  static Money? tryParse(String input, {String currency = 'PHP'}) {
    final String cleaned = input.trim().replaceAll(',', '').replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return null;
    }

    final RegExpMatch? match = RegExp(r'^(-?)(\d*)(?:\.(\d{0,2}))?$')
        .firstMatch(cleaned);
    if (match == null) {
      return null;
    }

    final String major = match.group(2) ?? '';
    final String minor = match.group(3) ?? '';
    if (major.isEmpty && minor.isEmpty) {
      return null;
    }

    // Right-pad so '5' means 50 centavos, not 5.
    final String paddedMinor = minor.padRight(2, '0');

    final int majorValue = major.isEmpty ? 0 : int.parse(major);
    final int minorValue = paddedMinor.isEmpty ? 0 : int.parse(paddedMinor);
    final int total = majorValue * minorPerMajor + minorValue;

    return Money(
      minorUnits: match.group(1) == '-' ? -total : total,
      currency: currency,
    );
  }

  /// Formats for display: `₱2,450.50`.
  ///
  /// The one place an amount becomes a string. Locale-aware grouping, and the
  /// currency's own symbol rather than a hard-coded `₱` — a USD subscription
  /// showing a peso sign is worse than no symbol at all.
  String format({String? locale}) {
    final NumberFormat formatter = NumberFormat.simpleCurrency(
      locale: locale,
      name: currency,
    );

    return formatter.format(minorUnits / minorPerMajor);
  }

  /// Formats without the currency symbol: `2,450.50`. For inputs and tables where
  /// the currency is stated once in a header.
  String formatBare({String? locale}) => NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 2,
  ).format(minorUnits / minorPerMajor);

  Money operator +(Money other) {
    _assertSameCurrency(other);

    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);

    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Never negative. For "how much is still owed", where a negative would mean
  /// the bill has been overpaid and there is nothing left to show.
  Money clampToZero() => minorUnits < 0 ? Money.zero(currency) : this;

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);

    return minorUnits.compareTo(other.minorUnits);
  }

  /// Adding pesos to dollars is meaningless, and doing it silently produces a
  /// number that looks plausible. An assert catches it in development without
  /// costing anything in release.
  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Cannot combine $currency with ${other.currency}. '
      'Convert first, deliberately.',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money($minorUnits $currency)';
}
