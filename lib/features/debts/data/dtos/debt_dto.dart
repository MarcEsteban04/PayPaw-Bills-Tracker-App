import '../../../../core/data/row_reader.dart';
import '../../../../core/domain/money.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/new_debt.dart';

/// Maps a `public.debts` row to and from [Debt].
///
/// Hand-written rather than generated, for the reason `BillDto` gives: the
/// column names have to match `supabase/migrations/0008_debts.sql` exactly, and
/// a mismatch is a runtime failure rather than a compile error.
///
/// Three mappings carry real risk:
///
/// * **`principal_minor`** is minor units. It becomes [Money], never a double.
/// * **`incurred_on` and `due_on`** are SQL `date`s, sent as `YYYY-MM-DD`. They
///   are parsed as local dates at midnight rather than through `DateTime.parse`,
///   which would make a date-only value sensitive to the device's timezone.
/// * **`direction`** has no safe default — see [DebtDirection.parse]. A row that
///   does not name one is refused rather than guessed at, because guessing would
///   tell somebody they owe money they are in fact owed.
abstract final class DebtDto {
  static const String table = 'debts';

  // Column names, in one place. Referenced rather than repeated so a rename is
  // one edit and a typo is a compile error.
  static const String columnId = 'id';
  static const String columnUserId = 'user_id';
  static const String columnDirection = 'direction';
  static const String columnCounterpartyName = 'counterparty_name';
  static const String columnCounterpartyContact = 'counterparty_contact';
  static const String columnPrincipalMinor = 'principal_minor';
  static const String columnCurrency = 'currency';
  static const String columnIncurredOn = 'incurred_on';
  static const String columnDueOn = 'due_on';
  static const String columnNotes = 'notes';
  static const String columnSettledAt = 'settled_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  /// Every column, for a `select`. Explicit rather than `*`, so adding a column
  /// to the table does not silently change what the app fetches.
  static const String selectColumns =
      '$columnId, $columnUserId, $columnDirection, $columnCounterpartyName, '
      '$columnCounterpartyContact, $columnPrincipalMinor, $columnCurrency, '
      '$columnIncurredOn, $columnDueOn, $columnNotes, $columnSettledAt, '
      '$columnCreatedAt, $columnUpdatedAt';

  /// Reads a row.
  ///
  /// Throws [FormatException] on a row that cannot be a debt. The repository
  /// turns that into an `AppException`; failing loudly here beats a [Debt] whose
  /// direction was guessed.
  static Debt toEntity(Map<String, dynamic> row) {
    final String rawDirection = RowReader.requireString(
      row,
      columnDirection,
      table: table,
    );

    final DebtDirection? direction = DebtDirection.parse(rawDirection);

    if (direction == null) {
      throw FormatException(
        'debts.$columnDirection was "$rawDirection", which is neither '
        '"${DebtDirection.iOwe.wireValue}" nor '
        '"${DebtDirection.owedToMe.wireValue}".',
      );
    }

    return Debt(
      id: RowReader.requireString(row, columnId, table: table),
      userId: RowReader.requireString(row, columnUserId, table: table),
      direction: direction,
      counterpartyName: RowReader.requireString(
        row,
        columnCounterpartyName,
        table: table,
      ),
      counterpartyContact: row[columnCounterpartyContact] as String?,
      principal: Money(
        minorUnits: RowReader.requireInt(
          row,
          columnPrincipalMinor,
          table: table,
        ),
        currency: (row[columnCurrency] as String?) ?? 'PHP',
      ),
      incurredOn: RowReader.parseDate(
        RowReader.requireString(row, columnIncurredOn, table: table),
      ),
      // Nullable in the column and nullable here. Plenty of utang has no agreed
      // date, and a missing one is a fact rather than a fault.
      dueOn: switch (row[columnDueOn]) {
        final String value when value.isNotEmpty => RowReader.parseDate(value),
        _ => null,
      },
      notes: row[columnNotes] as String?,
      settledAt: RowReader.optionalTimestamp(row[columnSettledAt]),
      createdAt: RowReader.requireTimestamp(row, columnCreatedAt, table: table),
      updatedAt: RowReader.requireTimestamp(row, columnUpdatedAt, table: table),
    );
  }

  /// Values for an `insert`.
  ///
  /// Takes a [NewDebt], not a [Debt], and `user_id` comes from the caller rather
  /// than the draft — the repository takes it from the session so no call site
  /// can get it wrong. `settled_at` is not sent: a debt is not created repaid.
  static Map<String, dynamic> toInsert(
    NewDebt draft, {
    required String userId,
  }) {
    return <String, dynamic>{
      columnUserId: userId,
      columnDirection: draft.direction.wireValue,
      columnCounterpartyName: draft.counterpartyName.trim(),
      columnCounterpartyContact: _orNull(draft.counterpartyContact),
      columnPrincipalMinor: draft.principal.minorUnits,
      columnCurrency: draft.principal.currency,
      columnIncurredOn: RowReader.formatDate(draft.incurredOn),
      columnDueOn: draft.dueOn == null
          ? null
          : RowReader.formatDate(draft.dueOn!),
      columnNotes: _orNull(draft.notes),
    };
  }

  /// Values for an `update`.
  ///
  /// Excludes `user_id` as well as the database-owned columns: ownership is not
  /// an editable property, and sending it would be an update the RLS policy has
  /// to reject rather than one it never sees.
  ///
  /// Includes `settled_at`, which *is* editable — settling and reopening are
  /// updates to this column, and sending null is how a reopen says so.
  static Map<String, dynamic> toUpdate(Debt debt) {
    return <String, dynamic>{
      columnDirection: debt.direction.wireValue,
      columnCounterpartyName: debt.counterpartyName.trim(),
      columnCounterpartyContact: _orNull(debt.counterpartyContact),
      columnPrincipalMinor: debt.principal.minorUnits,
      columnCurrency: debt.principal.currency,
      columnIncurredOn: RowReader.formatDate(debt.incurredOn),
      columnDueOn: debt.dueOn == null
          ? null
          : RowReader.formatDate(debt.dueOn!),
      columnNotes: _orNull(debt.notes),
      columnSettledAt: debt.settledAt?.toUtc().toIso8601String(),
    };
  }

  /// Empty is not the same as absent: a blank contact means "none recorded",
  /// which is a null column, not an empty string that formats later as a stray
  /// blank line.
  static String? _orNull(String? value) {
    final String trimmed = value?.trim() ?? '';

    return trimmed.isEmpty ? null : trimmed;
  }
}
