import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/data/dtos/bill_dto.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/new_bill.dart';

/// The mapping between a `bills` row and a `Bill`.
///
/// The riskiest code in the feature: a wrong column name is not a compile error,
/// it is a runtime failure on a screen the user is already looking at. These
/// tests are the compile step the mapping does not get.
void main() {
  /// A row shaped exactly as PostgREST returns one.
  Map<String, dynamic> row({
    Object? amountMinor = 245050,
    Object? archivedAt,
    Object? categoryId,
    Object? currency = 'PHP',
  }) => <String, dynamic>{
    'id': 'bill-1',
    'user_id': 'user-1',
    'category_id': categoryId,
    'recurring_bill_id': null,
    'name': 'Meralco electricity',
    'payee': 'Meralco',
    'amount_minor': amountMinor,
    'currency': currency,
    'due_on': '2026-09-05',
    'notes': 'account 1234',
    'archived_at': archivedAt,
    'created_at': '2026-08-24T02:15:00Z',
    'updated_at': '2026-08-24T02:15:00Z',
  };

  group('reading a row', () {
    test('maps every field', () {
      final Bill bill = BillDto.toEntity(row());

      expect(bill.id, 'bill-1');
      expect(bill.userId, 'user-1');
      expect(bill.name, 'Meralco electricity');
      expect(bill.payee, 'Meralco');
      expect(bill.notes, 'account 1234');
      expect(bill.categoryId, isNull);
      expect(bill.recurringBillId, isNull);
      expect(bill.archivedAt, isNull);
      expect(bill.isArchived, isFalse);
    });

    test('amount_minor becomes Money, not a double', () {
      // The whole schema is built on exactness; a double here would undo it.
      expect(BillDto.toEntity(row()).amount, const Money.php(245050));
    });

    test('accepts a bigint sent as a string', () {
      // PostgREST sends bigint as a number, but switches to a string past 2^53.
      // Amounts never get that large, and relying on that is how a crash reaches
      // production.
      expect(
        BillDto.toEntity(row(amountMinor: '245050')).amount,
        const Money.php(245050),
      );
    });

    test('respects the row currency', () {
      expect(BillDto.toEntity(row(currency: 'USD')).amount.currency, 'USD');
    });

    test('falls back to PHP when currency is absent', () {
      expect(BillDto.toEntity(row(currency: null)).amount.currency, 'PHP');
    });

    test('due_on is a date, not a moment', () {
      final DateTime dueOn = BillDto.toEntity(row()).dueOn;

      // The day must be the day regardless of where the device is. Parsed through
      // DateTime.parse alone, a date-only value picks up a timezone and can slide
      // to the 4th or the 6th.
      expect(dueOn.year, 2026);
      expect(dueOn.month, 9);
      expect(dueOn.day, 5);
      expect(dueOn.hour, 0);
      expect(dueOn.minute, 0);
    });

    test('reads archived_at when set', () {
      final Bill bill = BillDto.toEntity(
        row(archivedAt: '2026-08-24T05:00:00Z'),
      );

      expect(bill.archivedAt, isNotNull);
      expect(bill.isArchived, isTrue);
    });

    test('throws on a row that cannot be a bill', () {
      // Loud beats a Bill with a zero amount standing in for an unparseable row.
      for (final String missing in <String>[
        'id',
        'user_id',
        'name',
        'amount_minor',
        'due_on',
        'created_at',
      ]) {
        final Map<String, dynamic> broken = row()..remove(missing);

        expect(
          () => BillDto.toEntity(broken),
          throwsA(isA<FormatException>()),
          reason: 'a row without $missing should be rejected',
        );
      }
    });
  });

  group('writing a row', () {
    final Bill bill = Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Meralco electricity',
      payee: 'Meralco',
      amount: const Money.php(245050),
      dueOn: DateTime(2026, 9, 5),
      notes: 'account 1234',
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );

    final NewBill draft = NewBill(
      name: bill.name,
      payee: bill.payee,
      amount: bill.amount,
      dueOn: bill.dueOn,
      notes: bill.notes,
    );

    test('insert omits what the database owns', () {
      final Map<String, dynamic> values = BillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      // A client-sent updated_at would be overwritten by the trigger anyway, and
      // a client-sent id makes the common path more complicated than it needs.
      expect(values.containsKey('id'), isFalse);
      expect(values.containsKey('created_at'), isFalse);
      expect(values.containsKey('updated_at'), isFalse);
    });

    test('insert takes the owner from the caller, not the draft', () {
      // A NewBill has no userId at all, so a call site cannot pass the wrong one
      // — or somebody else's. The repository supplies it from the session.
      expect(BillDto.toInsert(draft, userId: 'user-1')['user_id'], 'user-1');
    });

    test('insert does not create a bill already archived', () {
      // The column defaults to null, and there is no state that wants a bill
      // filed away before it existed.
      expect(
        BillDto.toInsert(draft, userId: 'user-1').containsKey('archived_at'),
        isFalse,
      );
    });

    test('insert sends minor units and the currency', () {
      final Map<String, dynamic> values = BillDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['amount_minor'], 245050);
      expect(values['currency'], 'PHP');
    });

    test('insert sends due_on as a bare date', () {
      // toIso8601String() would append a time and a timezone, making the value
      // depend on where the device is.
      expect(BillDto.toInsert(draft, userId: 'user-1')['due_on'], '2026-09-05');
    });

    test('update omits user_id but keeps archived_at', () {
      // Ownership is not editable — sending it would be an update the RLS policy
      // has to reject rather than one it never sees. archived_at *is* editable:
      // archiving and restoring are both writes to that column.
      final Map<String, dynamic> values = BillDto.toUpdate(bill);

      expect(values.containsKey('user_id'), isFalse);
      expect(values.containsKey('id'), isFalse);
      expect(values.containsKey('archived_at'), isTrue);
    });

    test('round-trips through a row', () {
      final Map<String, dynamic> asRow =
          BillDto.toInsert(draft, userId: bill.userId)
            ..addAll(<String, dynamic>{
              'id': bill.id,
              'created_at': bill.createdAt.toIso8601String(),
              'updated_at': bill.updatedAt.toIso8601String(),
            });

      final Bill parsed = BillDto.toEntity(asRow);

      expect(parsed.name, bill.name);
      expect(parsed.amount, bill.amount);
      expect(parsed.dueOn, bill.dueOn);
      expect(parsed.payee, bill.payee);
      expect(parsed.notes, bill.notes);
    });
  });

  group('date formatting', () {
    test('pads month and day', () {
      expect(BillDto.formatDate(DateTime(2026, 1, 7)), '2026-01-07');
      expect(BillDto.formatDate(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('parses what it formats', () {
      final DateTime original = DateTime(2026, 2, 28);

      expect(BillDto.parseDate(BillDto.formatDate(original)), original);
    });
  });

  group('selectColumns', () {
    test('names every column the mapper reads', () {
      // A column missing here is a null the mapper then throws on, at runtime, on
      // a screen the user is looking at.
      for (final String column in <String>[
        BillDto.columnId,
        BillDto.columnUserId,
        BillDto.columnCategoryId,
        BillDto.columnRecurringBillId,
        BillDto.columnName,
        BillDto.columnPayee,
        BillDto.columnAmountMinor,
        BillDto.columnCurrency,
        BillDto.columnDueOn,
        BillDto.columnNotes,
        BillDto.columnArchivedAt,
        BillDto.columnCreatedAt,
        BillDto.columnUpdatedAt,
      ]) {
        expect(
          BillDto.selectColumns,
          contains(column),
          reason: '$column is read but not selected',
        );
      }
    });
  });
}
