import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_totals.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/dashboard/domain/entities/dashboard_mood.dart';

/// Which mascot the dashboard shows.
///
/// A rule about money, so it lives in the domain and is asserted here rather
/// than pumped and squinted at. Every case below is an artwork somebody has to
/// draw, which makes the list of them worth being explicit about.
void main() {
  BillWithStatus bill({
    required int amount,
    int paid = 0,
    BillStatus status = BillStatus.upcoming,
  }) => BillWithStatus(
    bill: Bill(
      id: 'bill-1',
      userId: 'user-1',
      name: 'Rent',
      amount: Money.php(amount),
      dueOn: DateTime(2026, 9, 20),
      createdAt: DateTime(2026, 8, 12),
      updatedAt: DateTime(2026, 8, 12),
    ),
    status: status,
    paid: Money.php(paid),
    outstanding: Money.php(amount - paid),
    today: DateTime(2026, 9, 3),
  );

  DashboardMood moodOf(List<BillWithStatus> bills, {bool hasOverdue = false}) =>
      DashboardMood.of(BillTotals.of(bills), hasOverdue: hasOverdue);

  test('nothing paid yet is the neutral face', () {
    expect(
      moodOf(<BillWithStatus>[bill(amount: 500000)]),
      DashboardMood.noneSettled,
    );
  });

  test('some of it paid is its own face', () {
    expect(
      moodOf(<BillWithStatus>[bill(amount: 500000, paid: 200000)]),
      DashboardMood.someSettled,
    );
  });

  test('all of it paid is its own face', () {
    expect(
      moodOf(<BillWithStatus>[
        bill(amount: 500000, paid: 500000, status: BillStatus.paid),
      ]),
      DashboardMood.allSettled,
    );
  });

  test('overpaid still counts as all of it', () {
    // A rounded-up transfer or a surcharge. The column permits paying more than
    // was billed, and "more than settled" is not a fifth mood.
    expect(
      moodOf(<BillWithStatus>[
        bill(amount: 500000, paid: 600000, status: BillStatus.paid),
      ]),
      DashboardMood.allSettled,
    );
  });

  group('overdue', () {
    test('outranks everything, however much is settled', () {
      // Somebody three quarters settled with one bill a fortnight late is not
      // three quarters of the way to fine. The late bill is the fact of their
      // week, and a mascot celebrating progress over it would be the app looking
      // away from the one thing it exists to point at.
      expect(
        moodOf(<BillWithStatus>[
          bill(amount: 500000, paid: 400000),
        ], hasOverdue: true),
        DashboardMood.overdue,
      );
    });

    test('even when the arithmetic says everything is paid', () {
      // Reachable: one bill settled in full, another past its date with a
      // credit against it. The dates disagree with the totals, and the dates
      // win.
      expect(
        moodOf(<BillWithStatus>[
          bill(amount: 500000, paid: 500000, status: BillStatus.paid),
        ], hasOverdue: true),
        DashboardMood.overdue,
      );
    });
  });

  group('an empty account', () {
    test('gets the neutral face, not the trophy', () {
      // Zero of zero is arithmetically complete, and putting a celebration on an
      // account with nothing in it reads as mockery the first time somebody
      // opens the app.
      expect(moodOf(const <BillWithStatus>[]), DashboardMood.noneSettled);
    });
  });

  test('every mood names a file, and no two share one', () {
    // The set is the list of artworks that have to exist. Two moods pointing at
    // one file would be a variant that silently never appears.
    final Set<String> paths = DashboardMood.values
        .map((DashboardMood mood) => mood.assetPath)
        .toSet();

    expect(paths, hasLength(DashboardMood.values.length));
    expect(
      paths.every((String path) => path.startsWith('assets/images/mascots/')),
      isTrue,
    );
  });
}
