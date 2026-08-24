import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_filter.dart';
import 'package:paypaw/features/bills/domain/entities/bill_sort.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';

/// The rule for what belongs in a filtered result set, and in what order.
///
/// Tested without a widget, which is the reason [BillFilter] lives in domain
/// despite looking like UI state: every one of these is a question about
/// inclusion, and none of them needs a screen to answer.
void main() {
  BillWithStatus bill({
    String id = 'bill-1',
    String name = 'Meralco electricity',
    String? payee,
    String? categoryId = 'cat-power',
    int amount = 245050,
    DateTime? dueOn,
    BillStatus status = BillStatus.upcoming,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: name,
      payee: payee,
      amount: Money.php(amount),
      dueOn: dueOn ?? DateTime(2026, 9, 20),
      categoryId: categoryId,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: const Money.php(0),
    outstanding: Money.php(amount),
    today: DateTime(2026, 9, 3),
  );

  List<String> names(List<BillWithStatus> bills) =>
      bills.map((BillWithStatus b) => b.bill.name).toList();

  group('an empty filter', () {
    test('admits everything and narrows nothing', () {
      // Empty sets mean "no filter", not "match nothing". A filter that started
      // by excluding everything would show an empty list on first open.
      const BillFilter filter = BillFilter.none;

      expect(filter.isNarrowed, isFalse);
      expect(filter.narrowCount, 0);
      expect(filter.matches(bill()), isTrue);
    });
  });

  group('search', () {
    test('matches the name, case-insensitively and part-way through', () {
      const BillFilter filter = BillFilter(query: 'ELEC');

      expect(filter.matches(bill()), isTrue);
      expect(filter.matches(bill(name: 'Maynilad water')), isFalse);
    });

    test('matches the payee too', () {
      // The provider is what people remember when the bill is named something
      // else — 'Internet' billed by Converge.
      const BillFilter filter = BillFilter(query: 'converge');

      expect(filter.matches(bill(name: 'Internet', payee: 'Converge')), isTrue);
    });

    test('does not match notes', () {
      // Notes hold account numbers and reminders to self. Matching them would
      // surface a bill for a reason invisible on the row that came back.
      final BillWithStatus item = BillWithStatus(
        bill: bill().bill.copyWith(notes: 'ask Ana about the rebate'),
        status: BillStatus.upcoming,
        paid: const Money.php(0),
        outstanding: const Money.php(245050),
        today: DateTime(2026, 9, 3),
      );

      expect(const BillFilter(query: 'rebate').matches(item), isFalse);
    });

    test('whitespace is not a search', () {
      const BillFilter filter = BillFilter(query: '   ');

      expect(filter.isNarrowed, isFalse);
      expect(filter.matches(bill(name: 'anything')), isTrue);
    });
  });

  group('status', () {
    test('admits only the chosen ones', () {
      const BillFilter filter = BillFilter(
        statuses: <BillStatus>{BillStatus.overdue, BillStatus.dueToday},
      );

      expect(filter.matches(bill(status: BillStatus.overdue)), isTrue);
      expect(filter.matches(bill(status: BillStatus.dueToday)), isTrue);
      expect(filter.matches(bill(status: BillStatus.paid)), isFalse);
    });

    test('an empty set still leaves archived bills out', () {
      // The one exception to "empty means everything". Archiving means "stop
      // showing me this", so the default view excludes them however wide it
      // otherwise is.
      final BillWithStatus archived = BillWithStatus(
        bill: bill().bill.copyWith(archivedAt: DateTime(2026, 8, 12)),
        status: BillStatus.archived,
        paid: const Money.php(0),
        outstanding: const Money.php(245050),
        today: DateTime(2026, 9, 3),
      );

      expect(BillFilter.none.matches(archived), isFalse);
      expect(BillFilter.none.matches(bill()), isTrue);
    });

    test('and selecting Archived is how they come back', () {
      final BillWithStatus archived = BillWithStatus(
        bill: bill().bill.copyWith(archivedAt: DateTime(2026, 8, 12)),
        status: BillStatus.archived,
        paid: const Money.php(0),
        outstanding: const Money.php(245050),
        today: DateTime(2026, 9, 3),
      );

      const BillFilter filter = BillFilter(
        statuses: <BillStatus>{BillStatus.archived},
      );

      expect(filter.matches(archived), isTrue);
      expect(filter.includesArchived, isTrue);
      // And the live bill is now the one excluded.
      expect(filter.matches(bill()), isFalse);
    });
  });

  group('category', () {
    test('admits only the chosen ones', () {
      const BillFilter filter = BillFilter(categoryIds: <String>{'cat-power'});

      expect(filter.matches(bill()), isTrue);
      expect(filter.matches(bill(categoryId: 'cat-water')), isFalse);
    });

    test('an uncategorised bill is excluded once any category is chosen', () {
      // Not treated as a wildcard: that would make the pill's count disagree
      // with the rows on screen.
      const BillFilter filter = BillFilter(categoryIds: <String>{'cat-power'});

      expect(filter.matches(bill(categoryId: null)), isFalse);
    });
  });

  group('due date', () {
    final BillWithStatus september = bill(dueOn: DateTime(2026, 9, 20));

    test('bounds are inclusive at both ends', () {
      // A range that excluded its own endpoints would drop the bill due on the
      // day the user picked, which is the one they were looking for.
      expect(
        BillFilter(
          dueFrom: DateTime(2026, 9, 20),
          dueTo: DateTime(2026, 9, 20),
        ).matches(september),
        isTrue,
      );
    });

    test('excludes what falls outside', () {
      expect(
        BillFilter(dueTo: DateTime(2026, 9, 19)).matches(september),
        isFalse,
      );
      expect(
        BillFilter(dueFrom: DateTime(2026, 9, 21)).matches(september),
        isFalse,
      );
    });

    test('a bound with a time on it still matches its own day', () {
      // The picker can hand back a moment rather than a date. Comparing them
      // whole would drop every bill due on the last day of the range.
      expect(
        BillFilter(dueTo: DateTime(2026, 9, 20, 14, 30)).matches(september),
        isTrue,
      );
    });

    test('one open end is a valid range', () {
      expect(BillFilter(dueFrom: DateTime(2026, 2)).matches(september), isTrue);
    });
  });

  group('amount', () {
    test('bounds the full amount, not the outstanding balance', () {
      // "Show me the bills over 2,000" is a question about the bill, not about
      // how much of it is left to pay.
      const BillFilter filter = BillFilter(minAmount: Money.php(200000));

      expect(filter.matches(bill(amount: 300000)), isTrue);
      expect(filter.matches(bill(amount: 150000)), isFalse);
    });

    test('bounds are inclusive', () {
      const BillFilter filter = BillFilter(
        minAmount: Money.php(300000),
        maxAmount: Money.php(300000),
      );

      expect(filter.matches(bill(amount: 300000)), isTrue);
    });
  });

  group('filters combine', () {
    test('every one has to pass', () {
      const BillFilter filter = BillFilter(
        query: 'meralco',
        statuses: <BillStatus>{BillStatus.overdue},
      );

      expect(filter.matches(bill(status: BillStatus.overdue)), isTrue);
      // Right name, wrong status.
      expect(filter.matches(bill(status: BillStatus.paid)), isFalse);
    });

    test('and each counts once towards the badge', () {
      final BillFilter filter = BillFilter(
        query: 'meralco',
        statuses: const <BillStatus>{BillStatus.overdue},
        dueFrom: DateTime(2026, 9),
        dueTo: DateTime(2026, 9, 30),
        minAmount: const Money.php(100),
      );

      // Four things applied: a query, a status, a date range and an amount
      // range. The ranges count once each however many of their two bounds are
      // set — the user set one thing.
      expect(filter.narrowCount, 4);
    });

    test('sort is not a filter', () {
      // Reordering hides nothing, so counting it would put a "1 filter" badge on
      // a screen showing everything.
      const BillFilter filter = BillFilter(sort: BillSort.amountHighest);

      expect(filter.isNarrowed, isFalse);
      expect(filter.narrowCount, 0);
    });
  });

  group('sorting', () {
    final List<BillWithStatus> three = <BillWithStatus>[
      bill(id: '1', name: 'Charlie', amount: 300, dueOn: DateTime(2026, 9, 10)),
      bill(id: '2', name: 'alpha', amount: 100, dueOn: DateTime(2026, 9, 30)),
      bill(id: '3', name: 'Bravo', amount: 200, dueOn: DateTime(2026, 9, 20)),
    ];

    test('due soonest is the default', () {
      expect(names(BillFilter.none.apply(three)), <String>[
        'Charlie',
        'Bravo',
        'alpha',
      ]);
    });

    test('due latest reverses it', () {
      expect(
        names(const BillFilter(sort: BillSort.dueLatest).apply(three)),
        <String>['alpha', 'Bravo', 'Charlie'],
      );
    });

    test('largest and smallest first', () {
      expect(
        names(const BillFilter(sort: BillSort.amountHighest).apply(three)),
        <String>['Charlie', 'Bravo', 'alpha'],
      );
      expect(
        names(const BillFilter(sort: BillSort.amountLowest).apply(three)),
        <String>['alpha', 'Bravo', 'Charlie'],
      );
    });

    test('name is case-insensitive, so lowercase does not sort last', () {
      expect(
        names(const BillFilter(sort: BillSort.nameAtoZ).apply(three)),
        <String>['alpha', 'Bravo', 'Charlie'],
      );
    });

    test(
      'ties break by name, so the list does not shuffle between fetches',
      () {
        // Without a tie-break, two bills that compare equal keep whatever order
        // the fetch happened to return — which can change.
        final List<BillWithStatus> sameDay = <BillWithStatus>[
          bill(id: '1', name: 'Zebra', dueOn: DateTime(2026, 9, 10)),
          bill(id: '2', name: 'Apple', dueOn: DateTime(2026, 9, 10)),
        ];

        expect(names(BillFilter.none.apply(sameDay)), <String>[
          'Apple',
          'Zebra',
        ]);
      },
    );

    test('apply filters and orders in one pass', () {
      final List<BillWithStatus> result = const BillFilter(
        minAmount: Money.php(150),
        sort: BillSort.amountLowest,
      ).apply(three);

      expect(names(result), <String>['Bravo', 'Charlie']);
    });
  });

  group('clearing', () {
    test('keeps the order, because reordering is a preference', () {
      // "Clear filters" silently re-sorting the list would be a surprise.
      final BillFilter filter = BillFilter(
        query: 'x',
        statuses: const <BillStatus>{BillStatus.paid},
        dueFrom: DateTime(2026, 9),
        minAmount: const Money.php(100),
        sort: BillSort.nameAtoZ,
      ).cleared();

      expect(filter.isNarrowed, isFalse);
      expect(filter.sort, BillSort.nameAtoZ);
    });

    test('clearing a range sets it to null, which copyWith cannot', () {
      final BillFilter filter = BillFilter(
        dueFrom: DateTime(2026, 9),
        dueTo: DateTime(2026, 9, 30),
        minAmount: const Money.php(100),
      ).clearing(due: true);

      expect(filter.dueFrom, isNull);
      expect(filter.dueTo, isNull);
      // And leaves the rest alone.
      expect(filter.minAmount, const Money.php(100));
    });
  });

  group('equality', () {
    test('compares sets by content, not identity', () {
      // Set.== is identity, so without this every filter object a provider saw
      // would look like a change and rebuild everything watching it.
      expect(
        const BillFilter(statuses: <BillStatus>{BillStatus.paid}),
        const BillFilter(statuses: <BillStatus>{BillStatus.paid}),
      );
      expect(
        const BillFilter(statuses: <BillStatus>{BillStatus.paid}).hashCode,
        const BillFilter(statuses: <BillStatus>{BillStatus.paid}).hashCode,
      );
    });

    test('and notices a real difference', () {
      expect(
        const BillFilter(statuses: <BillStatus>{BillStatus.paid}),
        isNot(const BillFilter(statuses: <BillStatus>{BillStatus.overdue})),
      );
    });
  });
}
