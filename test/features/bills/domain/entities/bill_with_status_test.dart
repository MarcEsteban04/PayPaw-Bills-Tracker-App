import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/domain/entities/new_bill.dart';

void main() {
  Bill bill({DateTime? dueOn}) => Bill(
    id: 'bill-1',
    userId: 'user-1',
    name: 'Meralco electricity',
    amount: const Money.php(245050),
    dueOn: dueOn ?? DateTime(2026, 9, 5),
    createdAt: DateTime(2026, 8, 2),
    updatedAt: DateTime(2026, 8, 2),
  );

  BillWithStatus item({
    DateTime? dueOn,
    DateTime? today,
    int paid = 0,
    int outstanding = 245050,
    BillStatus? status = BillStatus.dueSoon,
  }) => BillWithStatus(
    bill: bill(dueOn: dueOn),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(outstanding),
    today: today ?? DateTime(2026, 9, 3),
  );

  group('BillWithStatus', () {
    test('keeps the stored bill reachable and separate', () {
      // Composed rather than flattened, so a call site can see which half it is
      // reading. `item.bill.name` is something the user typed; `item.status` is
      // something the database concluded.
      expect(item().bill.name, 'Meralco electricity');
      expect(item().id, item().bill.id);
    });

    test('isPartiallyPaid needs both a payment and a remainder', () {
      expect(item(paid: 100000, outstanding: 145050).isPartiallyPaid, isTrue);
      // Nothing paid.
      expect(item().isPartiallyPaid, isFalse);
      // Fully settled.
      expect(item(paid: 245050, outstanding: 0).isPartiallyPaid, isFalse);
    });

    test('daysUntilDue is counted against the row own date', () {
      // Not DateTime.now(). The view sends `today` in the user's zone precisely
      // so the count does not depend on the device — a phone in another zone
      // would otherwise disagree with the status sitting beside it.
      expect(item().daysUntilDue, 2);
      expect(item(today: DateTime(2026, 9, 5)).daysUntilDue, 0);
      expect(item(today: DateTime(2026, 9, 6)).daysUntilDue, -1);
    });

    test('daysUntilDue ignores any time of day', () {
      // Both sides are dates; a stray time must not turn 2 days into 1.
      expect(
        item(
          dueOn: DateTime(2026, 9, 5, 23, 59),
          today: DateTime(2026, 9, 3, 1),
        ).daysUntilDue,
        2,
      );
    });

    test('daysUntilDue survives a month boundary', () {
      expect(
        item(
          dueOn: DateTime(2026, 10, 2),
          today: DateTime(2026, 9, 30),
        ).daysUntilDue,
        2,
      );
    });

    test('an unknown status is allowed to be null', () {
      // The UI shows "unknown" rather than crashing on a status this build has
      // never heard of.
      expect(item(status: null).status, isNull);
    });

    test('equality is by value', () {
      expect(item(), item());
      expect(item().hashCode, item().hashCode);
      expect(item(), isNot(item(status: BillStatus.overdue)));
      expect(item(), isNot(item(paid: 1)));
    });
  });

  group('NewBill', () {
    NewBill draft() => NewBill(
      name: 'Maynilad water',
      amount: const Money.php(89000),
      dueOn: DateTime(2026, 10, 12),
    );

    test('carries no id, no timestamps and no owner', () {
      // The point of the type. A Bill would need invented values for all four,
      // and an invented timestamp is a lie some later code believes.
      //
      // Checked by construction: this compiles only while none of them exist.
      final NewBill created = draft();

      expect(created.name, 'Maynilad water');
      expect(created.amount, const Money.php(89000));
    });

    test('copyWith changes only what it is given', () {
      final NewBill updated = draft().copyWith(amount: const Money.php(95000));

      expect(updated.amount, const Money.php(95000));
      expect(updated.name, 'Maynilad water');
      expect(updated.dueOn, DateTime(2026, 10, 12));
    });

    test('equality is by value', () {
      expect(draft(), draft());
      expect(draft().hashCode, draft().hashCode);
      expect(draft(), isNot(draft().copyWith(name: 'Manila Water')));
    });
  });
}
