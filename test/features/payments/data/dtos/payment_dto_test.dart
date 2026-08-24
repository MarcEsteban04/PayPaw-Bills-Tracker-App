import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/payments/data/dtos/payment_dto.dart';
import 'package:paypaw/features/payments/domain/entities/payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment_method.dart';

/// The mapper between a `public.payments` row and [Payment].
///
/// The column names here have to match `supabase/migrations/0009_payments.sql`
/// exactly, and a mismatch is a runtime failure rather than a compile error —
/// which is the whole reason a hand-written mapper gets its own test.
void main() {
  Map<String, dynamic> row({
    Object? amountMinor = 60000,
    Object? method = 'gcash',
    Object? reference,
    Object? note,
    Object? billId = 'bill-1',
    Object? debtId,
  }) => <String, dynamic>{
    'id': 'pay-1',
    'user_id': 'user-1',
    'bill_id': billId,
    'debt_id': debtId,
    'amount_minor': amountMinor,
    'currency': 'PHP',
    'paid_at': '2026-08-14T09:30:00Z',
    'method': method,
    'reference': reference,
    'note': note,
    'created_at': '2026-08-14T09:30:05Z',
    'updated_at': '2026-08-14T09:30:05Z',
  };

  group('toEntity', () {
    test('reads a row', () {
      final Payment payment = PaymentDto.toEntity(row(reference: 'GC-8812'));

      expect(payment.id, 'pay-1');
      expect(payment.billId, 'bill-1');
      expect(payment.debtId, isNull);
      expect(payment.amount.minorUnits, 60000);
      expect(payment.amount.currency, 'PHP');
      expect(payment.method, PaymentMethod.gcash);
      expect(payment.reference, 'GC-8812');
    });

    test('the amount is minor units, never a double', () {
      // The exactness the whole schema is built on. A double here would undo it.
      expect(PaymentDto.toEntity(row()).amount.minorUnits, isA<int>());
      expect(PaymentDto.toEntity(row()).amount.format(), '₱600.00');
    });

    test('a bigint sent as a string still reads as a number', () {
      // PostgREST sends bigint as a JSON number, but a value beyond 2^53 arrives
      // as a string to preserve precision.
      expect(
        PaymentDto.toEntity(row(amountMinor: '60000')).amount.minorUnits,
        60000,
      );
    });

    test('paid_at comes back in the reader own timezone', () {
      // A timestamptz is a real moment, unlike a due date, and should be shown
      // where the reader is.
      expect(PaymentDto.toEntity(row()).paidAt.isUtc, isFalse);
    });

    test('an unknown method is null, not a throw', () {
      // The column is free text with a documented vocabulary, so it can grow
      // without an app release. A history that will not render because of one
      // unfamiliar word would be a bad trade.
      expect(PaymentDto.toEntity(row(method: 'crypto_somehow')).method, isNull);
      expect(PaymentDto.toEntity(row(method: null)).method, isNull);
    });

    test('a payment against a debt reads too', () {
      final Payment payment = PaymentDto.toEntity(
        row(billId: null, debtId: 'debt-1'),
      );

      expect(payment.billId, isNull);
      expect(payment.debtId, 'debt-1');
    });

    test('an unreadable amount throws rather than reading as zero', () {
      // A payment that silently reads as zero changes what the user believes
      // they still owe. That is worse than a visible failure.
      expect(
        () => PaymentDto.toEntity(row(amountMinor: null)),
        throwsFormatException,
      );
    });

    test('and the failure names the column', () {
      expect(
        () => PaymentDto.toEntity(row(amountMinor: 'not a number')),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('payments.amount_minor'),
          ),
        ),
      );
    });
  });

  test('selectColumns names every column the mapper reads', () {
    // `select('*')` would mean adding a column to the table silently changes what
    // the app fetches. Spelling them out only helps if the list stays complete.
    for (final String column in <String>[
      'id',
      'user_id',
      'bill_id',
      'debt_id',
      'amount_minor',
      'currency',
      'paid_at',
      'method',
      'reference',
      'note',
      'created_at',
      'updated_at',
    ]) {
      expect(PaymentDto.selectColumns, contains(column));
    }
  });
}
