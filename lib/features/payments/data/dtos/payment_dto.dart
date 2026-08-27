import '../../../../core/data/row_reader.dart';
import '../../../../core/domain/money.dart';
import '../../domain/entities/new_payment.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/payment_target.dart';

/// Maps a `public.payments` row to [Payment].
///
/// Hand-written for the same reason `BillDto` is: the column names have to match
/// `supabase/migrations/0009_payments.sql` exactly, and a mismatch is a runtime
/// failure rather than a compile error.
///
/// Writes since Sprint 37, which is when recording a payment arrived. There is
/// still no `toUpdate`: nothing edits a payment, and correcting one is a delete
/// and a re-entry rather than an edit — the amount is what the bank says.
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

  /// Values for an `insert`.
  ///
  /// `debt_id` is sent as null rather than omitted. The table's
  /// `payments_single_target` check counts non-nulls across both columns, and
  /// being explicit about the half that is empty is what makes the row's shape
  /// legible next to that constraint.
  ///
  /// `id`, `created_at` and `updated_at` are absent because the database owns
  /// them. Sending a client-side timestamp for `created_at` would make the audit
  /// trail depend on whether the user's phone clock is right.
  static Map<String, dynamic> toInsert(
    NewPayment draft, {
    required String userId,
  }) {
    return <String, dynamic>{
      columnUserId: userId,
      // Exactly one, which is what the check constraint requires and what the
      // target type guarantees. A switch rather than two nullable reads: adding
      // a third kind of target would fail to compile here rather than silently
      // insert a row with neither column set.
      columnBillId: switch (draft.target) {
        BillTarget(:final String id) => id,
        DebtTarget() => null,
      },
      columnDebtId: switch (draft.target) {
        DebtTarget(:final String id) => id,
        BillTarget() => null,
      },
      columnAmountMinor: draft.amount.minorUnits,
      columnCurrency: draft.amount.currency,
      // A timestamptz, so it goes over the wire as an instant with its offset —
      // unlike a due date, which is a date and is formatted as one. UTC because
      // the column stores UTC; PostgREST would accept the local offset too, but
      // then two devices in different timezones write the same moment two ways.
      columnPaidAt: draft.paidAt.toUtc().toIso8601String(),
      columnMethod: draft.method?.wireValue,
      columnReference: draft.reference,
      columnNote: draft.note,
    };
  }

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
