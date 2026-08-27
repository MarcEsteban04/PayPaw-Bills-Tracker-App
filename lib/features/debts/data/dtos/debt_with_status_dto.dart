import '../../../../core/data/row_reader.dart';
import '../../../../core/domain/money.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/debt_with_status.dart';

/// Maps a `public.debt_status` row to [DebtWithStatus].
///
/// Read-only. The view is a read model; writes go to `debts` through [DebtDto],
/// and offering a `toUpdate` here would invite somebody to try writing a derived
/// column back.
///
/// The column names have to match `0019_debt_status.sql` exactly — a mismatch is
/// a runtime failure rather than a compile error, which is why they are spelled
/// out where a reviewer can compare the two files.
abstract final class DebtWithStatusDto {
  static const String viewName = 'debt_status';

  /// The view names the key `debt_id`, not `id`. Aliased in the SQL so a row
  /// carrying both a debt and its totals cannot have two columns called `id`.
  static const String columnDebtId = 'debt_id';
  static const String columnUserId = 'user_id';
  static const String columnDirection = 'direction';
  static const String columnCounterpartyName = 'counterparty_name';
  static const String columnCounterpartyContact = 'counterparty_contact';
  static const String columnPrincipalMinor = 'principal_minor';
  static const String columnCurrency = 'currency';
  static const String columnRepaidMinor = 'repaid_minor';
  static const String columnOutstandingMinor = 'outstanding_minor';
  static const String columnLastPaidAt = 'last_paid_at';
  static const String columnPaymentCount = 'payment_count';
  static const String columnIsFullyRepaid = 'is_fully_repaid';
  static const String columnToday = 'today';
  static const String columnIncurredOn = 'incurred_on';
  static const String columnDueOn = 'due_on';
  static const String columnNotes = 'notes';
  static const String columnSettledAt = 'settled_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Every column, for a `select`. Explicit rather than `*`, so adding a column
  /// to the view does not silently change what the app fetches.
  static const String selectColumns =
      '$columnDebtId, $columnUserId, $columnDirection, '
      '$columnCounterpartyName, $columnCounterpartyContact, '
      '$columnPrincipalMinor, $columnCurrency, $columnRepaidMinor, '
      '$columnOutstandingMinor, $columnLastPaidAt, $columnPaymentCount, '
      '$columnIsFullyRepaid, $columnToday, $columnIncurredOn, $columnDueOn, '
      '$columnNotes, $columnSettledAt, $columnCreatedAt, $columnUpdatedAt';

  /// Reads a row.
  ///
  /// Throws [FormatException] on anything it cannot read — most of all a
  /// `direction` it does not recognise, which is refused rather than guessed for
  /// the reason `DebtDirection.parse` gives.
  static DebtWithStatus toEntity(Map<String, dynamic> row) {
    final String rawDirection = RowReader.requireString(
      row,
      columnDirection,
      table: viewName,
    );
    final DebtDirection? direction = DebtDirection.parse(rawDirection);

    if (direction == null) {
      throw FormatException(
        'debt_status.$columnDirection was "$rawDirection", which is neither '
        '"${DebtDirection.iOwe.wireValue}" nor '
        '"${DebtDirection.owedToMe.wireValue}".',
      );
    }

    final String currency = (row[columnCurrency] as String?) ?? 'PHP';

    return DebtWithStatus(
      debt: Debt(
        id: RowReader.requireString(row, columnDebtId, table: viewName),
        userId: RowReader.requireString(row, columnUserId, table: viewName),
        direction: direction,
        counterpartyName: RowReader.requireString(
          row,
          columnCounterpartyName,
          table: viewName,
        ),
        counterpartyContact: row[columnCounterpartyContact] as String?,
        principal: Money(
          minorUnits: RowReader.requireInt(
            row,
            columnPrincipalMinor,
            table: viewName,
          ),
          currency: currency,
        ),
        incurredOn: RowReader.parseDate(
          RowReader.requireString(row, columnIncurredOn, table: viewName),
        ),
        dueOn: switch (row[columnDueOn]) {
          final String value when value.isNotEmpty => RowReader.parseDate(
            value,
          ),
          _ => null,
        },
        notes: row[columnNotes] as String?,
        settledAt: RowReader.optionalTimestamp(row[columnSettledAt]),
        createdAt: RowReader.requireTimestamp(
          row,
          columnCreatedAt,
          table: viewName,
        ),
        updatedAt: RowReader.requireTimestamp(
          row,
          columnUpdatedAt,
          table: viewName,
        ),
      ),
      repaid: Money(
        minorUnits: RowReader.requireInt(
          row,
          columnRepaidMinor,
          table: viewName,
        ),
        currency: currency,
      ),
      outstanding: Money(
        minorUnits: RowReader.requireInt(
          row,
          columnOutstandingMinor,
          table: viewName,
        ),
        currency: currency,
      ),
      paymentCount: RowReader.requireInt(
        row,
        columnPaymentCount,
        table: viewName,
      ),
      isFullyRepaid: row[columnIsFullyRepaid] == true,
      // From the database, in the owner's own zone. Nothing here asks the device
      // clock, so a countdown cannot disagree with the row beside it.
      today: RowReader.parseDate(
        RowReader.requireString(row, columnToday, table: viewName),
      ),
      lastPaidAt: RowReader.optionalTimestamp(row[columnLastPaidAt]),
    );
  }
}
