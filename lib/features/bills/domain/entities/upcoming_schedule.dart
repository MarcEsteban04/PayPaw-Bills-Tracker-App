import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'bill_status.dart';
import 'bill_with_status.dart';

/// How soon a bill falls due, in the words people use.
///
/// Ordered by urgency, which is also chronological — the two only ever agree
/// because everything late has already been taken out.
enum DueWindow {
  today('Today'),
  tomorrow('Tomorrow'),
  thisWeek('Later this week'),
  nextWeek('Next week'),
  later('Later');

  const DueWindow(this.label);

  final String label;

  /// Whether this is the tail that gets summarised rather than listed.
  bool get isTail => this == DueWindow.later;
}

/// The bills in one window.
@immutable
class UpcomingGroup {
  const UpcomingGroup({
    required this.window,
    required this.bills,
    required this.total,
  });

  final DueWindow window;
  final List<BillWithStatus> bills;

  /// What the window costs. Carried so the summarised tail can state a figure
  /// without the screen re-adding it.
  final Money total;
}

/// What is coming, grouped by how soon.
///
/// ## Why named windows rather than dates
///
/// "Due in 6 days" is a subtraction the reader has to do before they know
/// whether it matters. "Next week" is the answer. The list rows still carry the
/// exact date; these headings are what make a list of ten scannable in one look.
///
/// ## Weeks are calendar weeks, not rolling ones
///
/// A rolling seven days is easier to compute and quietly wrong: on a Friday it
/// would file next Thursday under "this week", which is not what the words say.
/// Weeks run Monday to Sunday, matching `DateTime.weekday`.
///
/// The consequence is that on a Sunday "later this week" is empty and everything
/// lands in "tomorrow" or "next week". That is correct — there *is* no rest of
/// the week — and empty windows are dropped rather than shown.
///
/// ## Nothing late is in here
///
/// Overdue bills have their own section, above. A bill that is both late and due
/// "today" is late, and the dashboard says so once.
@immutable
class UpcomingSchedule {
  const UpcomingSchedule({required this.groups});

  factory UpcomingSchedule.of(
    List<BillWithStatus> bills, {
    required DateTime today,
  }) {
    final String currency = bills.isEmpty
        ? 'PHP'
        : bills.first.outstanding.currency;
    final DateTime start = _dateOnly(today);

    // Sunday of the current week. `weekday` is 1 (Monday) to 7 (Sunday), so this
    // is today plus however many days are left in it.
    final DateTime endOfWeek = start.add(Duration(days: 7 - start.weekday));
    final DateTime endOfNextWeek = endOfWeek.add(const Duration(days: 7));

    final Map<DueWindow, List<BillWithStatus>> buckets =
        <DueWindow, List<BillWithStatus>>{};

    final List<BillWithStatus> owing =
        bills
            .where(
              (BillWithStatus b) =>
                  !b.bill.isArchived &&
                  b.status != BillStatus.overdue &&
                  (b.status?.isOutstanding ?? false),
            )
            .toList()
          ..sort(
            (BillWithStatus a, BillWithStatus b) =>
                a.bill.dueOn.compareTo(b.bill.dueOn),
          );

    for (final BillWithStatus bill in owing) {
      final DueWindow window = _windowFor(
        _dateOnly(bill.bill.dueOn),
        today: start,
        endOfWeek: endOfWeek,
        endOfNextWeek: endOfNextWeek,
      );

      buckets.putIfAbsent(window, () => <BillWithStatus>[]).add(bill);
    }

    return UpcomingSchedule(
      // Enum order, not insertion order: the windows have a fixed sequence and a
      // map's iteration order is whatever arrived first.
      groups: <UpcomingGroup>[
        for (final DueWindow window in DueWindow.values)
          if (buckets[window] case final List<BillWithStatus> inWindow)
            UpcomingGroup(
              window: window,
              bills: inWindow,
              total: inWindow.fold(
                Money(minorUnits: 0, currency: currency),
                (Money running, BillWithStatus bill) =>
                    running + bill.outstanding,
              ),
            ),
      ],
    );
  }

  /// Only the windows that have something in them, soonest first.
  final List<UpcomingGroup> groups;

  bool get isEmpty => groups.isEmpty;

  /// Everything except the summarised tail.
  List<UpcomingGroup> get listed =>
      groups.where((UpcomingGroup g) => !g.window.isTail).toList();

  /// The tail, or null when nothing falls beyond next week.
  UpcomingGroup? get tail =>
      groups.where((UpcomingGroup g) => g.window.isTail).firstOrNull;

  /// Which window a date belongs to.
  ///
  /// First match wins, and the order matters: on a Sunday, tomorrow is Monday,
  /// which is also the start of next week. "Tomorrow" is the more useful of the
  /// two answers, so it is checked first.
  static DueWindow _windowFor(
    DateTime due, {
    required DateTime today,
    required DateTime endOfWeek,
    required DateTime endOfNextWeek,
  }) {
    if (!due.isAfter(today)) {
      // Today, or earlier. Anything genuinely late was filtered out already, so
      // what reaches here is due today — a bill dated yesterday that the view
      // has not yet called overdue belongs with today rather than in a window
      // that has passed.
      return DueWindow.today;
    }
    if (due == today.add(const Duration(days: 1))) {
      return DueWindow.tomorrow;
    }
    if (!due.isAfter(endOfWeek)) {
      return DueWindow.thisWeek;
    }
    if (!due.isAfter(endOfNextWeek)) {
      return DueWindow.nextWeek;
    }

    return DueWindow.later;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
