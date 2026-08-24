import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';

void main() {
  Bill bill({String? categoryId, DateTime? archivedAt, String? notes}) => Bill(
    id: 'bill-1',
    userId: 'user-1',
    name: 'Meralco electricity',
    amount: const Money.php(245050),
    dueOn: DateTime(2026, 9, 5),
    createdAt: DateTime(2026, 8, 2),
    updatedAt: DateTime(2026, 8, 2),
    categoryId: categoryId,
    archivedAt: archivedAt,
    notes: notes,
  );

  group('Bill', () {
    test('copyWith changes only what it is given', () {
      final Bill updated = bill().copyWith(amount: const Money.php(300000));

      expect(updated.amount, const Money.php(300000));
      expect(updated.name, 'Meralco electricity');
      expect(updated.id, 'bill-1');
    });

    test('copyWith cannot clear a nullable field', () {
      // Passing null to copyWith means "leave it alone", which is why `clearing`
      // exists. Pinning the behaviour so nobody later "fixes" copyWith into
      // treating null as a removal and silently wipes fields on every edit.
      final Bill original = bill(categoryId: 'cat-1', notes: 'keep me');
      final Bill unchanged = original.copyWith();

      expect(unchanged.categoryId, 'cat-1');
      expect(unchanged.notes, 'keep me');
    });

    test('clearing removes exactly the named fields', () {
      final Bill original = bill(
        categoryId: 'cat-1',
        notes: 'note',
        archivedAt: DateTime(2026, 8, 20),
      );

      final Bill cleared = original.clearing(category: true, archived: true);

      expect(cleared.categoryId, isNull);
      expect(cleared.archivedAt, isNull);
      expect(cleared.notes, 'note');
    });

    test('isArchived follows archivedAt', () {
      expect(bill().isArchived, isFalse);
      expect(bill(archivedAt: DateTime(2026, 8, 20)).isArchived, isTrue);
    });

    test('equality is by value', () {
      expect(bill(), bill());
      expect(bill().hashCode, bill().hashCode);
      expect(bill(), isNot(bill(categoryId: 'cat-1')));
    });
  });

  group('BillStatus', () {
    test('parses every value the view produces', () {
      // These strings are the contract with 0012_bill_status.sql. A change on
      // either side without the other shows up here.
      expect(BillStatus.tryParse('upcoming'), BillStatus.upcoming);
      expect(BillStatus.tryParse('due_soon'), BillStatus.dueSoon);
      expect(BillStatus.tryParse('partially_paid'), BillStatus.partiallyPaid);
      expect(BillStatus.tryParse('overdue'), BillStatus.overdue);
      expect(BillStatus.tryParse('paid'), BillStatus.paid);
      expect(BillStatus.tryParse('archived'), BillStatus.archived);
    });

    test('returns null for anything else', () {
      // A status added to the view should surface as "unknown" in the UI, not as
      // a crash on a screen the user was only reading — and not as a wrong
      // status, which is worse than none.
      expect(BillStatus.tryParse('settled'), isNull);
      expect(BillStatus.tryParse('dueSoon'), isNull);
      expect(BillStatus.tryParse(''), isNull);
      expect(BillStatus.tryParse(null), isNull);
    });

    test('isOutstanding covers exactly the ones still owing money', () {
      expect(BillStatus.upcoming.isOutstanding, isTrue);
      expect(BillStatus.dueSoon.isOutstanding, isTrue);
      expect(BillStatus.partiallyPaid.isOutstanding, isTrue);
      expect(BillStatus.overdue.isOutstanding, isTrue);
      expect(BillStatus.paid.isOutstanding, isFalse);
      expect(BillStatus.archived.isOutstanding, isFalse);
    });

    test('needsAttention is only the two urgent ones', () {
      expect(BillStatus.dueSoon.needsAttention, isTrue);
      expect(BillStatus.overdue.needsAttention, isTrue);
      expect(BillStatus.upcoming.needsAttention, isFalse);
      expect(BillStatus.partiallyPaid.needsAttention, isFalse);
      expect(BillStatus.paid.needsAttention, isFalse);
    });

    test('every value round-trips through its wire value', () {
      for (final BillStatus status in BillStatus.values) {
        expect(BillStatus.tryParse(status.wireValue), status);
      }
    });
  });
}
