/// Reads one column out of a PostgREST row, or says exactly which one was wrong.
///
/// Extracted from `BillDto`, which had these as public statics so the bill view's
/// DTO could share them. That worked while bills were the only table with a
/// mapper; a payments DTO calling `BillDto.requireInt` would be a payment mapper
/// depending on the bills feature for arithmetic, which is the kind of import
/// that makes a feature-first layout stop meaning anything.
///
/// Every reader names the table in its failure, because "column missing" on its
/// own is a bug report nobody can act on. The repository turns a [FormatException]
/// from here into a `ServerException`; failing loudly beats an entity with a zero
/// amount standing in for a row nobody could parse.
abstract final class RowReader {
  static String requireString(
    Map<String, dynamic> row,
    String column, {
    required String table,
  }) {
    final Object? value = row[column];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('$table.$column missing or not a string: $value');
  }

  /// Accepts an `int` and a numeric `String`.
  ///
  /// PostgREST sends `bigint` as a JSON number, but a value beyond 2^53 arrives
  /// as a string to preserve precision. Amounts never get that large, and relying
  /// on that is how a crash reaches production.
  static int requireInt(
    Map<String, dynamic> row,
    String column, {
    required String table,
  }) {
    final Object? value = row[column];
    if (value is int) {
      return value;
    }
    if (value is String) {
      final int? parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }

    throw FormatException('$table.$column missing or not an integer: $value');
  }

  static DateTime requireTimestamp(
    Map<String, dynamic> row,
    String column, {
    required String table,
  }) {
    final DateTime? parsed = optionalTimestamp(row[column]);
    if (parsed != null) {
      return parsed;
    }

    throw FormatException('$table.$column missing or not a timestamp');
  }

  static DateTime? optionalTimestamp(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    // toLocal: timestamptz arrives in UTC, and a timestamp shown to a user should
    // be in their own time.
    return DateTime.tryParse(value)?.toLocal();
  }

  /// Parses a SQL `date` (`YYYY-MM-DD`) as a local date at midnight.
  ///
  /// Not `DateTime.parse`, which would make a date-only value sensitive to the
  /// device's timezone — a due date is the same day everywhere.
  static DateTime parseDate(String value) {
    final List<String> parts = value.split('-');
    if (parts.length < 3) {
      throw FormatException('Not a date: $value');
    }

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      // A `date` column sends exactly YYYY-MM-DD, but a timestamp reaching this
      // path would carry a time; take the day and drop the rest.
      int.parse(parts[2].split('T').first),
    );
  }

  /// Formats a date for a SQL `date` column.
  ///
  /// Never `toIso8601String()`, which would append a time and a timezone and make
  /// the value depend on where the device is.
  static String formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }
}
