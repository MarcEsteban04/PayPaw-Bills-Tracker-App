import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/debts/data/dtos/debt_with_status_dto.dart';
import 'package:paypaw/features/debts/domain/entities/debt_with_status.dart';
import 'package:paypaw/features/payments/domain/entities/new_payment.dart';
import 'package:paypaw/features/payments/domain/entities/payment_target.dart';

/// What is left on a debt, and what a payment against one points at.
void main() {
  Map<String, dynamic> row({
    int principal = 500000,
    int repaid = 0,
    int payments = 0,
    bool fullyRepaid = false,
    Object? dueOn = '2026-09-30',
    Object? settledAt,
    String today = '2026-09-03',
  }) => <String, dynamic>{
    'debt_id': 'debt-1',
    'user_id': 'user-1',
    'direction': 'i_owe',
    'counterparty_name': 'Tita Ana',
    'counterparty_contact': null,
    'principal_minor': principal,
    'currency': 'PHP',
    'repaid_minor': repaid,
    'outstanding_minor': (principal - repaid).clamp(0, principal),
    'last_paid_at': null,
    'payment_count': payments,
    'is_fully_repaid': fullyRepaid,
    'today': today,
    'incurred_on': '2026-08-12',
    'due_on': dueOn,
    'notes': null,
    'settled_at': settledAt,
    'created_at': '2026-08-12T02:30:00Z',
    'updated_at': '2026-08-12T02:30:00Z',
  };

  group('the balance', () {
    test('is what the view says, not something recomputed here', () {
      // The subtraction lives in SQL. A client doing it again would be a second
      // definition of "outstanding", and the day they disagree somebody is told
      // they still owe money they have paid back.
      final DebtWithStatus item = DebtWithStatusDto.toEntity(
        row(repaid: 200000, payments: 2),
      );

      expect(item.repaid, const Money.php(200000));
      expect(item.outstanding, const Money.php(300000));
      expect(item.paymentCount, 2);
    });

    test('counts instalments, because that is what they are here', () {
      // This schema has no separate instalment plan. A debt paid in chunks is a
      // debt with several payments against it.
      expect(DebtWithStatusDto.toEntity(row(payments: 3)).paymentCount, 3);
    });

    test('reports progress, clamped', () {
      expect(DebtWithStatusDto.toEntity(row(repaid: 250000)).progress, 0.5);
      // An overpayment is real — somebody hands over a round number — and a bar
      // past its own end is not.
      expect(DebtWithStatusDto.toEntity(row(repaid: 600000)).progress, 1);
    });

    test('is partially repaid only in between', () {
      expect(DebtWithStatusDto.toEntity(row()).isPartiallyRepaid, isFalse);
      expect(
        DebtWithStatusDto.toEntity(row(repaid: 100000)).isPartiallyRepaid,
        isTrue,
      );
      expect(
        DebtWithStatusDto.toEntity(row(repaid: 500000, fullyRepaid: true))
            .isPartiallyRepaid,
        isFalse,
      );
    });
  });

  group('settled and fully repaid', () {
    test('are different questions and can disagree', () {
      // The numbers being square does not close utang, and closing it does not
      // mean the numbers are. The last hundred pesos gets waved off; a debt
      // stays open because something else was promised.
      final DebtWithStatus squareButOpen = DebtWithStatusDto.toEntity(
        row(repaid: 500000, fullyRepaid: true),
      );
      final DebtWithStatus closedButShort = DebtWithStatusDto.toEntity(
        row(repaid: 100000, settledAt: '2026-09-02T01:00:00Z'),
      );

      expect(squareButOpen.isFullyRepaid, isTrue);
      expect(squareButOpen.isSettled, isFalse);

      expect(closedButShort.isFullyRepaid, isFalse);
      expect(closedButShort.isSettled, isTrue);
    });
  });

  group('being late', () {
    test('uses the database\'s today, not the device clock', () {
      // The view computes it in the owner's own zone. A countdown against a
      // wrong phone clock would disagree with the date printed beside it.
      expect(
        DebtWithStatusDto.toEntity(row(dueOn: '2026-09-02')).isOverdue,
        isTrue,
      );
      expect(
        DebtWithStatusDto.toEntity(row(dueOn: '2026-09-04')).isOverdue,
        isFalse,
      );
    });

    test('never applies without an agreed date', () {
      expect(DebtWithStatusDto.toEntity(row(dueOn: null)).isOverdue, isFalse);
    });
  });

  test('every column it selects is one it can read back', () {
    // The select list and the reader drifting apart is a failure that still
    // type-checks and then arrives as a missing key on a device.
    final Set<String> selected = DebtWithStatusDto.selectColumns
        .split(',')
        .map((String column) => column.trim())
        .toSet();

    expect(selected, row().keys.toSet());
  });

  group('a payment target', () {
    test('is exactly one thing, which is what the check constraint says', () {
      // The nullable pair this replaced could be both or neither, and the
      // compiler could not tell.
      final NewPayment against = NewPayment(
        target: const PaymentTarget.debt('debt-1'),
        amount: const Money.php(100000),
        paidAt: DateTime(2026, 9, 2),
      );

      expect(against.target, isA<DebtTarget>());
      expect(against.target.id, 'debt-1');
    });

    test('distinguishes a bill from a debt with the same id', () {
      expect(
        const PaymentTarget.bill('x') == const PaymentTarget.debt('x'),
        isFalse,
      );
    });
  });
}
