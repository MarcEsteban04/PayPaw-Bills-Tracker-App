import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/domain/entities/upcoming_schedule.dart';

/// Sorting what is coming into "today", "next week" and so on.
///
/// The boundaries are where this can be wrong in a way nobody notices: a bill
/// filed one window too far out still appears, still says the right date, and
/// simply reads as less urgent than it is. Tests are the only thing that catch
/// that, so the edges get more attention here than the middles.
void main() {
  // Wednesday. Deliberate — a midweek anchor has a real "rest of this week" and
  // a real "next week", so the two are distinguishable. Sunday gets its own
  // group below precisely because it does not.
  final DateTime wednesday = DateTime(2026, 8, 26);

  BillWithStatus billDue(
    DateTime dueOn, {
    String id = 'bill',
    int outstanding = 100000,
    BillStatus? status = BillStatus.dueSoon,
    bool archived = false,
    DateTime? today,
  }) => BillWithStatus(
    bill: Bill(
      id: id,
      userId: 'user-1',
      name: 'Bill $id',
      amount: Money.php(outstanding),
      dueOn: dueOn,
      archivedAt: archived ? DateTime(2026, 8, 2) : null,
      createdAt: DateTime(2026, 8, 2),
      updatedAt: DateTime(2026, 8, 2),
    ),
    status: status,
    paid: const Money.php(0),
    outstanding: Money.php(outstanding),
    today: today ?? wednesday,
  );

  UpcomingSchedule scheduleOf(List<BillWithStatus> bills, {DateTime? today}) =>
      UpcomingSchedule.of(bills, today: today ?? wednesday);

  List<DueWindow> windowsOf(UpcomingSchedule schedule) =>
      schedule.groups.map((UpcomingGroup g) => g.window).toList();

  group('which window a date lands in', () {
    test('today is today', () {
      expect(
        windowsOf(scheduleOf(<BillWithStatus>[billDue(wednesday)])),
        <DueWindow>[DueWindow.today],
      );
    });

    test('tomorrow is its own window, not "later this week"', () {
      // Tomorrow is inside this week too. It is the more useful of the two
      // answers, so it wins.
      expect(
        windowsOf(scheduleOf(<BillWithStatus>[billDue(DateTime(2026, 8, 27))])),
        <DueWindow>[DueWindow.tomorrow],
      );
    });

    test('the rest of this week runs to Sunday', () {
      // Wednesday the 26th; Sunday the 30th is the last day that counts as
      // this week.
      expect(
        windowsOf(
          scheduleOf(<BillWithStatus>[
            billDue(DateTime(2026, 8, 28), id: 'fri'),
            billDue(DateTime(2026, 8, 30), id: 'sun'),
          ]),
        ),
        <DueWindow>[DueWindow.thisWeek],
      );
    });

    test('and Monday is next week, not day five of a rolling seven', () {
      // The whole reason weeks are calendar weeks. A rolling window would file
      // Monday the 31st under "this week", which is not what the words say.
      expect(
        windowsOf(scheduleOf(<BillWithStatus>[billDue(DateTime(2026, 8, 31))])),
        <DueWindow>[DueWindow.nextWeek],
      );
    });

    test('next week ends on its Sunday, and the day after is the tail', () {
      final UpcomingSchedule schedule = scheduleOf(<BillWithStatus>[
        billDue(DateTime(2026, 9, 6), id: 'last-of-next-week'),
        billDue(DateTime(2026, 9, 7), id: 'beyond'),
      ]);

      expect(windowsOf(schedule), <DueWindow>[
        DueWindow.nextWeek,
        DueWindow.later,
      ]);
      expect(schedule.tail?.bills.single.id, 'beyond');
    });
  });

  group('the Sunday edge', () {
    // On a Sunday there is no "rest of this week" — the week ends today. The
    // arithmetic has to survive that rather than producing an empty heading or
    // filing tomorrow under next week.
    final DateTime sunday = DateTime(2026, 8, 30);

    test('tomorrow beats next week even though Monday starts it', () {
      final UpcomingSchedule schedule = scheduleOf(<BillWithStatus>[
        billDue(DateTime(2026, 8, 31), today: sunday),
      ], today: sunday);

      expect(windowsOf(schedule), <DueWindow>[DueWindow.tomorrow]);
    });

    test('"later this week" simply does not appear', () {
      final UpcomingSchedule schedule = scheduleOf(<BillWithStatus>[
        billDue(sunday, id: 'today', today: sunday),
        billDue(DateTime(2026, 9, 2), id: 'wed', today: sunday),
      ], today: sunday);

      expect(windowsOf(schedule), <DueWindow>[
        DueWindow.today,
        DueWindow.nextWeek,
      ]);
    });
  });

  group('what is left out', () {
    test('anything already late — it has its own section above', () {
      // A bill that is both late and dated today is late, and the dashboard
      // says so once.
      expect(
        scheduleOf(<BillWithStatus>[
          billDue(wednesday, status: BillStatus.overdue),
        ]).isEmpty,
        isTrue,
      );
    });

    test('archived bills, for the reason they are left out everywhere', () {
      expect(
        scheduleOf(<BillWithStatus>[billDue(wednesday, archived: true)])
            .isEmpty,
        isTrue,
      );
    });

    test('and anything settled', () {
      expect(
        scheduleOf(<BillWithStatus>[
          billDue(wednesday, status: BillStatus.paid),
        ]).isEmpty,
        isTrue,
      );
    });

    test('empty windows are dropped rather than shown as bare headings', () {
      final UpcomingSchedule schedule = scheduleOf(<BillWithStatus>[
        billDue(wednesday, id: 'today'),
        billDue(DateTime(2026, 9, 20), id: 'far'),
      ]);

      expect(windowsOf(schedule), <DueWindow>[
        DueWindow.today,
        DueWindow.later,
      ]);
    });

    test('nothing at all is empty rather than an error', () {
      expect(scheduleOf(const <BillWithStatus>[]).isEmpty, isTrue);
      expect(scheduleOf(const <BillWithStatus>[]).tail, isNull);
    });
  });

  group('what each window carries', () {
    final UpcomingSchedule schedule = scheduleOf(<BillWithStatus>[
      billDue(DateTime(2026, 9, 25), id: 'far-b', outstanding: 30000),
      billDue(wednesday, id: 'today-b', outstanding: 50000),
      billDue(DateTime(2026, 9, 20), id: 'far-a', outstanding: 20000),
      billDue(wednesday, id: 'today-a', outstanding: 15000),
    ]);

    test('groups come out in window order, not insertion order', () {
      // The bills were handed over shuffled. A map's iteration order is
      // whatever arrived first, which would put "later" above "today".
      expect(windowsOf(schedule), <DueWindow>[
        DueWindow.today,
        DueWindow.later,
      ]);
    });

    test('bills inside a window are soonest first', () {
      expect(
        schedule.tail?.bills.map((BillWithStatus b) => b.id).toList(),
        <String>['far-a', 'far-b'],
      );
    });

    test(
      'each window totals what it costs, so the tail can state a figure',
      () {
        // The summarised row shows a number instead of rows; that number has to
        // come from somewhere, and re-adding it in the widget would be a second
        // definition of the same sum.
        expect(schedule.groups.first.total, const Money.php(65000));
        expect(schedule.tail?.total, const Money.php(50000));
      },
    );

    test('listed excludes the tail, which is what gets summarised', () {
      expect(
        schedule.listed.map((UpcomingGroup g) => g.window).toList(),
        <DueWindow>[DueWindow.today],
      );
      expect(schedule.tail?.window, DueWindow.later);
    });
  });
}
