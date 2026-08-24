import '../../../../core/data/row_reader.dart';
import '../../../../core/domain/money.dart';
import '../../domain/entities/new_recurring_bill.dart';
import '../../domain/entities/recurrence.dart';
import '../../domain/entities/recurrence_frequency.dart';
import '../../domain/entities/recurring_bill.dart';

/// Maps a `public.recurring_bills` row to and from [RecurringBill].
///
/// Hand-written for the same reason `BillDto` is: the column names have to match
/// `supabase/migrations/0005_recurring_bills.sql` exactly, and a mismatch is a
/// runtime failure rather than a compile error.
///
/// The interesting part is that seven columns collapse into one [Recurrence] and
/// back. The row is flat because SQL is flat; the entity is not, because the
/// schedule has rules of its own.
abstract final class RecurringBillDto {
  static const String tableName = 'recurring_bills';

  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnCategoryId = 'category_id';
  static const String columnKind = 'kind';
  static const String columnName = 'name';
  static const String columnPayee = 'payee';
  static const String columnAmountMinor = 'amount_minor';
  static const String columnCurrency = 'currency';
  static const String columnFrequency = 'frequency';
  static const String columnIntervalCount = 'interval_count';
  static const String columnDayOfMonth = 'day_of_month';
  static const String columnWeekday = 'weekday';
  static const String columnMonthOfYear = 'month_of_year';
  static const String columnStartsOn = 'starts_on';
  static const String columnEndsOn = 'ends_on';
  static const String columnNextDueOn = 'next_due_on';
  static const String columnIsActive = 'is_active';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Every column, for a `select`. Explicit rather than `*`, so adding a column to
  /// the table does not silently change what the app fetches.
  static const String selectColumns =
      '$columnId, $columnUserId, $columnCategoryId, $columnKind, $columnName, '
      '$columnPayee, $columnAmountMinor, $columnCurrency, $columnFrequency, '
      '$columnIntervalCount, $columnDayOfMonth, $columnWeekday, '
      '$columnMonthOfYear, $columnStartsOn, $columnEndsOn, $columnNextDueOn, '
      '$columnIsActive, $columnCreatedAt, $columnUpdatedAt';

  /// Reads a row.
  ///
  /// Throws [FormatException] on a row that cannot be a recurring bill. That
  /// includes an unrecognised `frequency`: unlike a bill's status, a schedule the
  /// app cannot read is not something to render as "unknown" and move on from —
  /// every date it would produce would be wrong, and it is the thing generation
  /// acts on.
  static RecurringBill toEntity(Map<String, dynamic> row) {
    final String frequencyValue = RowReader.requireString(
      row,
      columnFrequency,
      table: tableName,
    );
    final RecurrenceFrequency? frequency = RecurrenceFrequency.tryParse(
      frequencyValue,
    );

    if (frequency == null) {
      throw FormatException(
        '$tableName.$columnFrequency is not a frequency this build knows: '
        '$frequencyValue',
      );
    }

    return RecurringBill(
      id: RowReader.requireString(row, columnId, table: tableName),
      userId: RowReader.requireString(row, columnUserId, table: tableName),
      categoryId: row[columnCategoryId] as String?,
      kind: RecurringBillKind.parse(row[columnKind] as String?),
      name: RowReader.requireString(row, columnName, table: tableName),
      payee: row[columnPayee] as String?,
      amount: Money(
        minorUnits: RowReader.requireInt(
          row,
          columnAmountMinor,
          table: tableName,
        ),
        currency: (row[columnCurrency] as String?) ?? 'PHP',
      ),
      recurrence: Recurrence(
        frequency: frequency,
        intervalCount: RowReader.requireInt(
          row,
          columnIntervalCount,
          table: tableName,
        ),
        dayOfMonth: _optionalInt(row[columnDayOfMonth]),
        weekday: _optionalInt(row[columnWeekday]),
        monthOfYear: _optionalInt(row[columnMonthOfYear]),
        startsOn: RowReader.parseDate(
          RowReader.requireString(row, columnStartsOn, table: tableName),
        ),
        endsOn: _optionalDate(row[columnEndsOn]),
      ),
      nextDueOn: RowReader.parseDate(
        RowReader.requireString(row, columnNextDueOn, table: tableName),
      ),
      // Defaults to true rather than throwing: the column is `not null default
      // true`, so a missing value means the row predates something rather than
      // that the template is paused. Guessing "paused" would silently stop
      // generating bills the user is still expecting.
      isActive: (row[columnIsActive] as bool?) ?? true,
      createdAt: RowReader.requireTimestamp(
        row,
        columnCreatedAt,
        table: tableName,
      ),
      updatedAt: RowReader.requireTimestamp(
        row,
        columnUpdatedAt,
        table: tableName,
      ),
    );
  }

  /// Values for an `insert`.
  ///
  /// `user_id` comes from the caller rather than the draft, because the draft
  /// deliberately has no owner. `next_due_on` comes from the draft's recurrence —
  /// the column is `not null` with no default, and the rule's first occurrence is
  /// the only correct value at creation.
  static Map<String, dynamic> toInsert(
    NewRecurringBill draft, {
    required String userId,
  }) {
    final DateTime? first = draft.nextDueOn;
    if (first == null) {
      // Only reachable if a caller skipped `validate()`. Failing here beats
      // sending a null into a `not null` column and reading the Postgres error.
      throw StateError(
        'NewRecurringBill has no first occurrence; call validate() first.',
      );
    }

    return <String, dynamic>{
      columnUserId: userId,
      columnCategoryId: draft.categoryId,
      columnKind: draft.kind.wireValue,
      columnName: draft.name.trim(),
      columnPayee: draft.payee?.trim(),
      columnAmountMinor: draft.amount.minorUnits,
      columnCurrency: draft.amount.currency,
      columnIsActive: draft.isActive,
      columnNextDueOn: RowReader.formatDate(first),
      ..._recurrenceColumns(draft.recurrence),
    };
  }

  /// Values for an `update`.
  ///
  /// Excludes `user_id` and the database-owned timestamps. Ownership is not an
  /// editable property, and sending it would be an update the RLS policy has to
  /// reject rather than one it never sees.
  ///
  /// Includes `next_due_on`, which *is* editable — advancing the bookmark after
  /// generating an occurrence is an update to this column, and so is a skip.
  static Map<String, dynamic> toUpdate(RecurringBill bill) {
    return <String, dynamic>{
      columnCategoryId: bill.categoryId,
      columnKind: bill.kind.wireValue,
      columnName: bill.name.trim(),
      columnPayee: bill.payee?.trim(),
      columnAmountMinor: bill.amount.minorUnits,
      columnCurrency: bill.amount.currency,
      columnIsActive: bill.isActive,
      columnNextDueOn: RowReader.formatDate(bill.nextDueOn),
      ..._recurrenceColumns(bill.recurrence),
    };
  }

  /// The seven schedule columns, in one place so insert and update cannot differ.
  ///
  /// The fields a frequency does not use are sent as null rather than left out.
  /// Omitting them would leave a stale `month_of_year` behind on a rule changed
  /// from yearly to weekly, and `recurring_bills_recurrence_shape` does not catch
  /// that — the constraint checks that the needed fields are present, not that the
  /// unneeded ones are absent.
  static Map<String, dynamic> _recurrenceColumns(Recurrence recurrence) {
    return <String, dynamic>{
      columnFrequency: recurrence.frequency.wireValue,
      columnIntervalCount: recurrence.intervalCount,
      columnDayOfMonth: recurrence.frequency.needsWeekday
          ? null
          : recurrence.dayOfMonth,
      columnWeekday: recurrence.frequency.needsWeekday
          ? recurrence.weekday
          : null,
      columnMonthOfYear: recurrence.frequency.needsMonthOfYear
          ? recurrence.monthOfYear
          : null,
      columnStartsOn: RowReader.formatDate(recurrence.startsOn),
      columnEndsOn: recurrence.endsOn == null
          ? null
          : RowReader.formatDate(recurrence.endsOn!),
    };
  }

  /// Accepts an `int` and a numeric `String`, and passes null through.
  ///
  /// The recurrence columns are nullable `int`s, so `RowReader.requireInt` is the
  /// wrong tool — a null `weekday` on a monthly rule is correct, not a bad row.
  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static DateTime? _optionalDate(Object? value) =>
      value is String && value.isNotEmpty ? RowReader.parseDate(value) : null;
}
