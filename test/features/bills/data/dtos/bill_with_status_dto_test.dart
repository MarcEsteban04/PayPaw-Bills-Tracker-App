import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/data/dtos/bill_dto.dart';
import 'package:paypaw/features/bills/data/dtos/bill_with_status_dto.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';

/// The mapping between a `bill_status` row and a [BillWithStatus].
void main() {
  Map<String, dynamic> row({
    Object? status = 'due_soon',
    Object? paidMinor = 0,
    Object? outstandingMinor = 245050,
    Object? lastPaidAt,
    Object? today = '2026-09-03',
    Object? currency = 'PHP',
  }) => <String, dynamic>{
    'bill_id': 'bill-1',
    'user_id': 'user-1',
    'category_id': null,
    'recurring_bill_id': null,
    'name': 'Meralco electricity',
    'payee': 'Meralco',
    'amount_minor': 245050,
    'currency': currency,
    'due_on': '2026-09-05',
    'notes': null,
    'archived_at': null,
    'created_at': '2026-08-24T02:15:00Z',
    'updated_at': '2026-08-24T02:15:00Z',
    'status': status,
    'paid_minor': paidMinor,
    'outstanding_minor': outstandingMinor,
    'last_paid_at': lastPaidAt,
    'today': today,
  };

  group('reading a view row', () {
    test('maps the bill half through BillDto', () {
      // One definition of how a bill is read, used by both the table and the
      // view. The view renames the key to bill_id, which is the only difference.
      final BillWithStatus item = BillWithStatusDto.toEntity(row());

      expect(item.bill.id, 'bill-1');
      expect(item.bill.name, 'Meralco electricity');
      expect(item.bill.amount, const Money.php(245050));
      expect(item.bill.dueOn, DateTime(2026, 9, 5));
    });

    test('maps the derived half', () {
      final BillWithStatus item = BillWithStatusDto.toEntity(
        row(
          status: 'partially_paid',
          paidMinor: 100000,
          outstandingMinor: 145050,
          lastPaidAt: '2026-09-01T04:00:00Z',
        ),
      );

      expect(item.status, BillStatus.partiallyPaid);
      expect(item.paid, const Money.php(100000));
      expect(item.outstanding, const Money.php(145050));
      expect(item.lastPaidAt, isNotNull);
      expect(item.isPartiallyPaid, isTrue);
    });

    test('paid and outstanding carry the bill currency', () {
      // The view has no currency of its own for these — they are sums of the
      // bill's amount. A Money defaulting to PHP on a USD bill would format a
      // dollar total with a peso sign.
      final BillWithStatus item = BillWithStatusDto.toEntity(
        row(currency: 'USD'),
      );

      expect(item.paid.currency, 'USD');
      expect(item.outstanding.currency, 'USD');
      expect(item.bill.amount.currency, 'USD');
    });

    test('an unrecognised status is null, not an exception', () {
      // A status added to the view should show as unknown on a screen the user
      // was only scrolling, not crash it.
      final BillWithStatus item = BillWithStatusDto.toEntity(
        row(status: 'written_off'),
      );

      expect(item.status, isNull);
      // Everything else still read, which is the point of degrading rather than
      // throwing.
      expect(item.bill.name, 'Meralco electricity');
      expect(item.outstanding, const Money.php(245050));
    });

    test('no payments means no last-paid date', () {
      expect(BillWithStatusDto.toEntity(row()).lastPaidAt, isNull);
    });

    test('today is a date, and it comes from the database', () {
      // The column exists so the day is the user's day rather than the device's.
      // Parsed as a local date at midnight; through DateTime.parse the zone could
      // move it, which would let the row's own status contradict its own date.
      final DateTime today = BillWithStatusDto.toEntity(row()).today;

      expect(today, DateTime(2026, 9, 3));
      expect(today.hour, 0);
    });

    test('daysUntilDue counts from that date, not from the device clock', () {
      // Due the 5th, "today" the 3rd.
      expect(BillWithStatusDto.toEntity(row()).daysUntilDue, 2);

      expect(
        BillWithStatusDto.toEntity(row(today: '2026-09-05')).daysUntilDue,
        0,
      );
      expect(
        BillWithStatusDto.toEntity(row(today: '2026-09-08')).daysUntilDue,
        -3,
      );
    });

    test('accepts bigint totals sent as strings', () {
      final BillWithStatus item = BillWithStatusDto.toEntity(
        row(paidMinor: '100000', outstandingMinor: '145050'),
      );

      expect(item.paid, const Money.php(100000));
      expect(item.outstanding, const Money.php(145050));
    });

    test('throws on a row that cannot be one', () {
      for (final String missing in <String>[
        'bill_id',
        'amount_minor',
        'paid_minor',
        'outstanding_minor',
        'today',
      ]) {
        expect(
          () => BillWithStatusDto.toEntity(row()..remove(missing)),
          throwsA(isA<FormatException>()),
          reason: 'a row without $missing should be rejected',
        );
      }
    });
  });

  group('column names against migration 0014', () {
    // The check that catches the dangerous mistake. Every name is a string the
    // compiler cannot verify, and a wrong one is a 400 from PostgREST at runtime.
    late String sql;

    setUpAll(() {
      final File file = File(
        'supabase/migrations/0014_bill_status_with_details.sql',
      );
      expect(
        file.existsSync(),
        isTrue,
        reason:
            '${file.path} is missing — run from the project root, or the '
            'migration was renamed and this test needs updating',
      );
      sql = file.readAsStringSync();
    });

    test('every derived column is in the view', () {
      for (final String column in <String>[
        BillWithStatusDto.columnBillId,
        BillWithStatusDto.columnPaidMinor,
        BillWithStatusDto.columnOutstandingMinor,
        BillWithStatusDto.columnLastPaidAt,
        BillWithStatusDto.columnToday,
        BillWithStatusDto.columnStatus,
      ]) {
        expect(
          sql,
          contains(column),
          reason: '$column is read but not produced by the view',
        );
      }
    });

    test('the view name matches', () {
      expect(sql, contains('public.${BillWithStatusDto.viewName}'));
    });

    test('the appended display columns really were appended', () {
      // 0014's whole purpose. Without these the repository would need a second
      // query and a client-side join, which is what the migration removed.
      for (final String column in <String>[
        BillDto.columnName,
        BillDto.columnPayee,
        BillDto.columnCategoryId,
        BillDto.columnCurrency,
        BillDto.columnRecurringBillId,
        BillDto.columnNotes,
        BillDto.columnArchivedAt,
        BillDto.columnCreatedAt,
        BillDto.columnUpdatedAt,
      ]) {
        expect(
          sql,
          contains('b.$column'),
          reason: '$column is selected from the view but not in it',
        );
      }
    });

    test('the view is security_invoker', () {
      // Without this a view over `bills` runs as its definer and ignores RLS —
      // returning every user's bills while looking like it works perfectly. The
      // single most consequential line in the file.
      expect(sql, contains('security_invoker = true'));
    });

    test('every status the view emits is a value BillStatus knows', () {
      // Both sides of the contract, checked against each other. A status added to
      // the view without a matching enum value would silently read as unknown.
      final Iterable<String> emitted = RegExp(r"then '(\w+)'|else '(\w+)'")
          .allMatches(sql)
          .map((RegExpMatch m) => m.group(1) ?? m.group(2)!);

      expect(emitted, isNotEmpty, reason: 'the status CASE was not found');

      for (final String status in emitted) {
        expect(
          BillStatus.tryParse(status),
          isNotNull,
          reason: "the view emits '$status', which BillStatus cannot parse",
        );
      }
    });
  });
}
