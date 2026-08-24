import '../../../../core/domain/money.dart';
import '../../domain/entities/bill.dart';

/// Maps a `public.bills` row to and from [Bill].
///
/// Hand-written rather than generated, deliberately. The column names have to
/// match `supabase/migrations/0007_bills.sql` exactly, and a mismatch is a
/// runtime failure rather than a compile error — so the value of having them
/// spelled out where a reviewer can compare the two files outweighs the
/// boilerplate that json_serializable would have removed. (It is still in
/// dev_dependencies; when there are a dozen of these, revisit.)
///
/// Two mappings carry real risk and are handled explicitly:
///
/// * **`amount_minor`** is minor units. It becomes [Money], never a double. A
///   `double` here would undo the exactness the whole schema is built on.
/// * **`due_on`** is a SQL `date`, sent as `YYYY-MM-DD`. It is parsed as a local
///   date at midnight, not through `DateTime.parse` alone, because that would
///   make a date-only value sensitive to the device's timezone.
abstract final class BillDto {
  // Column names, in one place. Referenced rather than repeated so a rename is
  // one edit and a typo is a compile error.
  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnCategoryId = 'category_id';
  static const String columnRecurringBillId = 'recurring_bill_id';
  static const String columnName = 'name';
  static const String columnPayee = 'payee';
  static const String columnAmountMinor = 'amount_minor';
  static const String columnCurrency = 'currency';
  static const String columnDueOn = 'due_on';
  static const String columnNotes = 'notes';
  static const String columnArchivedAt = 'archived_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Every column, for a `select`. Explicit rather than `*`, so adding a column
  /// to the table does not silently change what the app fetches.
  static const String selectColumns =
      '$columnId, $columnUserId, $columnCategoryId, $columnRecurringBillId, '
      '$columnName, $columnPayee, $columnAmountMinor, $columnCurrency, '
      '$columnDueOn, $columnNotes, $columnArchivedAt, $columnCreatedAt, '
      '$columnUpdatedAt';

  /// Reads a row.
  ///
  /// Throws [FormatException] on a row that cannot be a bill. The repository
  /// turns that into an `AppException`; failing loudly here beats a `Bill` with a
  /// zero amount standing in for a row nobody could parse.
  static Bill toEntity(Map<String, dynamic> row) {
    return Bill(
      id: _requireString(row, columnId),
      userId: _requireString(row, columnUserId),
      categoryId: row[columnCategoryId] as String?,
      recurringBillId: row[columnRecurringBillId] as String?,
      name: _requireString(row, columnName),
      payee: row[columnPayee] as String?,
      amount: Money(
        minorUnits: _requireInt(row, columnAmountMinor),
        currency: (row[columnCurrency] as String?) ?? 'PHP',
      ),
      dueOn: parseDate(_requireString(row, columnDueOn)),
      notes: row[columnNotes] as String?,
      archivedAt: _optionalTimestamp(row[columnArchivedAt]),
      createdAt: _requireTimestamp(row, columnCreatedAt),
      updatedAt: _requireTimestamp(row, columnUpdatedAt),
    );
  }

  /// Values for an `insert`.
  ///
  /// Omits `id`, `created_at` and `updated_at`: the database owns all three, and
  /// sending a client-side `updated_at` would be overwritten by the trigger
  /// anyway. Sending `id` is possible — the entity can carry a client-generated
  /// uuid — but leaving it out keeps the common path simple.
  static Map<String, dynamic> toInsert(Bill bill) {
    return <String, dynamic>{
      columnUserId: bill.userId,
      columnCategoryId: bill.categoryId,
      columnRecurringBillId: bill.recurringBillId,
      columnName: bill.name,
      columnPayee: bill.payee,
      columnAmountMinor: bill.amount.minorUnits,
      columnCurrency: bill.amount.currency,
      columnDueOn: formatDate(bill.dueOn),
      columnNotes: bill.notes,
      columnArchivedAt: bill.archivedAt?.toUtc().toIso8601String(),
    };
  }

  /// Values for an `update`.
  ///
  /// Excludes `user_id` as well as the database-owned columns. Ownership is not
  /// an editable property, and sending it would be an update the RLS policy has
  /// to reject rather than one it never sees.
  static Map<String, dynamic> toUpdate(Bill bill) {
    final Map<String, dynamic> values = toInsert(bill)..remove(columnUserId);

    return values;
  }

  /// Parses a SQL `date` (`YYYY-MM-DD`) as a local date at midnight.
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

  static String _requireString(Map<String, dynamic> row, String column) {
    final Object? value = row[column];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('bills.$column missing or not a string: $value');
  }

  /// Accepts an `int` and a numeric `String`.
  ///
  /// PostgREST sends `bigint` as a JSON number, but a value beyond 2^53 arrives
  /// as a string to preserve precision. Amounts never get that large, and relying
  /// on that is how a crash reaches production.
  static int _requireInt(Map<String, dynamic> row, String column) {
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

    throw FormatException('bills.$column missing or not an integer: $value');
  }

  static DateTime _requireTimestamp(Map<String, dynamic> row, String column) {
    final DateTime? parsed = _optionalTimestamp(row[column]);
    if (parsed != null) {
      return parsed;
    }

    throw FormatException('bills.$column missing or not a timestamp');
  }

  static DateTime? _optionalTimestamp(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    // toLocal: timestamptz arrives in UTC, and a timestamp shown to a user should
    // be in their own time.
    return DateTime.tryParse(value)?.toLocal();
  }
}
