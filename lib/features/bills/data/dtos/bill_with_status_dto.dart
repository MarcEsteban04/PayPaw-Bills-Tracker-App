import '../../../../core/domain/money.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_status.dart';
import '../../domain/entities/bill_with_status.dart';
import 'bill_dto.dart';

/// Maps a `public.bill_status` row to [BillWithStatus].
///
/// Read-only: there is no `toInsert` here, because a view is not something a
/// client writes. Writes go through [BillDto] to the table.
///
/// The view's columns are the table's plus five derived ones, so the shared names
/// come from [BillDto] rather than being restated — a rename in the table is then
/// one edit, and the two files cannot disagree about what a column is called.
/// Compare against `supabase/migrations/0014_bill_status_with_details.sql`.
abstract final class BillWithStatusDto {
  static const String viewName = 'bill_status';

  /// The view calls the bill's primary key `bill_id`, not `id` — it is joining
  /// three tables and `id` would be ambiguous. The single most likely place for a
  /// wrong column name in this file.
  static const String columnBillId = 'bill_id';

  static const String columnPaidMinor = 'paid_minor';
  static const String columnOutstandingMinor = 'outstanding_minor';
  static const String columnLastPaidAt = 'last_paid_at';
  static const String columnToday = 'today';
  static const String columnStatus = 'status';

  /// Every column, for a `select`. Explicit rather than `*` so adding a column to
  /// the view does not silently change what the app fetches over the wire.
  static const String selectColumns =
      '$columnBillId, ${BillDto.columnUserId}, ${BillDto.columnCategoryId}, '
      '${BillDto.columnRecurringBillId}, ${BillDto.columnName}, '
      '${BillDto.columnPayee}, ${BillDto.columnAmountMinor}, '
      '${BillDto.columnCurrency}, ${BillDto.columnDueOn}, '
      '${BillDto.columnNotes}, ${BillDto.columnArchivedAt}, '
      '${BillDto.columnCreatedAt}, ${BillDto.columnUpdatedAt}, '
      '$columnPaidMinor, $columnOutstandingMinor, $columnLastPaidAt, '
      '$columnToday, $columnStatus';

  /// Reads a view row.
  ///
  /// Throws [FormatException] on a row that cannot be one. The repository turns
  /// that into an `AppException`.
  static BillWithStatus toEntity(Map<String, dynamic> row) {
    // The bill half is mapped by BillDto, which expects `id`. Handing it the
    // renamed key rather than duplicating thirteen lines of mapping: one
    // definition of how a bill is read, used by both the table and the view.
    final Bill bill = BillDto.toEntity(<String, dynamic>{
      ...row,
      BillDto.columnId: row[columnBillId],
    });

    final String currency = bill.amount.currency;

    return BillWithStatus(
      bill: bill,
      // tryParse, not a lookup that throws: an unrecognised status is shown as
      // unknown rather than crashing a list the user was only scrolling.
      status: BillStatus.tryParse(row[columnStatus] as String?),
      paid: Money(
        minorUnits: BillDto.requireInt(row, columnPaidMinor),
        currency: currency,
      ),
      outstanding: Money(
        minorUnits: BillDto.requireInt(row, columnOutstandingMinor),
        currency: currency,
      ),
      lastPaidAt: BillDto.optionalTimestamp(row[columnLastPaidAt]),
      // A `date`, like due_on — parsed as a local date at midnight rather than
      // through DateTime.parse, which would let the device's zone move the day.
      // This column exists precisely so the day comes from the database.
      today: BillDto.parseDate(BillDto.requireString(row, columnToday)),
    );
  }
}
