import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../domain/entities/calendar_month.dart';

/// Today, as the database worked it out.
///
/// Read off any bill row rather than from the device clock, for the reason
/// `BillWithStatus.today` exists: a phone in another zone would light a
/// different square than the one the statuses beside it are computed against,
/// and a calendar disagreeing with the list it came from is worse than either
/// being wrong alone.
///
/// Null while the bills are loading, and null for an account with no bills at
/// all — there is no row to read it from. The screen falls back to the device
/// clock there, which is safe precisely because there is nothing to contradict.
final Provider<DateTime?> calendarTodayProvider = Provider<DateTime?>(
  (Ref ref) => ref.watch(billsProvider).value?.firstOrNull?.today,
);

/// The month on screen.
///
/// Held here rather than in the screen's state so that stepping through months
/// survives a tab switch. The calendar is one of four destinations in the shell,
/// and coming back to it having been reset to today would undo whatever the user
/// was looking at.
class CalendarMonthController extends Notifier<CalendarMonth> {
  @override
  CalendarMonth build() {
    // Today's month, from the same source the grid highlights against. Before
    // the bills arrive there is nothing to read, and the device clock is the
    // only answer available — it is corrected on the first load, before the
    // month is ever painted with data in it.
    final DateTime today = ref.read(calendarTodayProvider) ?? DateTime.now();

    return CalendarMonth.of(today);
  }

  void next() => state = state.next;

  void previous() => state = state.previous;

  /// Jumps to the month containing [date].
  void showMonthOf(DateTime date) =>
      state = CalendarMonth.of(date, firstWeekday: state.firstWeekday);

  /// Back to today's month.
  ///
  /// Takes the date rather than reading it, because the caller is a widget that
  /// already has it and the fallback belongs in one place.
  void showToday(DateTime today) => showMonthOf(today);
}

final NotifierProvider<CalendarMonthController, CalendarMonth>
calendarMonthProvider =
    NotifierProvider<CalendarMonthController, CalendarMonth>(
      CalendarMonthController.new,
    );

/// Every bill that is not archived, keyed by the day it is due.
///
/// ## Why a map and not a search per cell
///
/// The grid asks forty-two times what is due on a date. Filtering the whole list
/// for each cell is forty-two passes over every bill on every repaint, and the
/// answer is the same each time. This is built once per change to the bills.
///
/// ## Archived bills are left out
///
/// They were put away, and a square marked because of one would be the calendar
/// insisting on something the user has already dismissed. Settled bills *do*
/// appear: "this was paid on time" is part of what a month view is for, and
/// Sprint 45 gives it its own indicator.
///
/// The keys are `DateTime`s at midnight — see [CalendarMonth.dateOnly]. A due
/// date carrying a time would never match a grid cell, and the lookup would
/// silently find nothing rather than fail.
final Provider<AsyncValue<Map<DateTime, List<BillWithStatus>>>>
billsByDueDateProvider =
    Provider<AsyncValue<Map<DateTime, List<BillWithStatus>>>>((Ref ref) {
      return ref.watch(billsProvider).whenData((List<BillWithStatus> all) {
        final Map<DateTime, List<BillWithStatus>> byDate =
            <DateTime, List<BillWithStatus>>{};

        for (final BillWithStatus item in all) {
          if (item.bill.isArchived) {
            continue;
          }

          byDate
              .putIfAbsent(
                CalendarMonth.dateOnly(item.bill.dueOn),
                () => <BillWithStatus>[],
              )
              .add(item);
        }

        return byDate;
      });
    });
