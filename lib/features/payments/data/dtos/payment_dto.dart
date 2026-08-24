import '../../../../core/data/row_reader.dart';
import '../../../../core/domain/money.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_method.dart';

/// Maps a `public.payments` row to [Payment].
///
/// Hand-written for the same reason `BillDto` is: the column names have to match
/// `supabase/migrations/0009_payments.sql` exactly, and a mismatch is a runtime
/// failure rather than a compile error.
///
/// Read-only. There is no `toInsert` because nothing writes payments yet, and an
/// unused mapper is a mapper nobody tested.
abstract final class PaymentDto {
  static const String tableName = 'payments';

  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnBillId = 'bill_id';
  static const String columnDebtId = 'debt_id';
  static const String columnAmountMinor = 'amount_minor';
  static const String columnCurrency = 'currency';
  static const String columnPaidAt = 'paid_at';
  static const String columnMethod = 'method';
  static const String columnReference = 'reference';
  static const String columnNote = 'note';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Every column, for a `select`. Explicit rather than `*`, so adding a column
  /// to the table does not silently change what the app fetches.
  static const String selectColumns =
      '$columnId, $columnUserId, $columnBillId, $columnDebtId, '
      '$columnAmountMinor, $columnCurrency, $columnPaidAt, $columnMethod, '
      '$columnReference, $columnNote, $columnCreatedAt, $columnUpdatedAt';

  /// Reads a row.
  ///
  /// Throws [FormatException] on a row that cannot be a payment. A payment that
  /// reads as zero because a column would not parse is worse than a visible
  /// failure: it silently changes what the user believes they still owe.
  static Payment toEntity(Map<String, dynamic> row) {
    return Payment(
      id: RowReader.requireString(row, columnId, table: tableName),
      userId: RowReader.requireString(row, columnUserId, table: tableName),
      billId: row[columnBillId] as String?,
      debtId: row[columnDebtId] as String?,
      amount: Money(
        minorUnits: RowReader.requireInt(
          row,
          columnAmountMinor,
          table: tableName,
        ),
        currency: (row[columnCurrency] as String?) ?? 'PHP',
      ),
      paidAt: RowReader.requireTimestamp(row, columnPaidAt, table: tableName),
      // Null for a method this build has not been taught, rather than a throw.
      // The vocabulary is free text by design and can grow without an app
      // release; a history that will not render because of one unfamiliar word
      // would be a bad trade.
      method: PaymentMethod.tryParse(row[columnMethod] as String?),
      reference: row[columnReference] as String?,
      note: row[columnNote] as String?,
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
}
