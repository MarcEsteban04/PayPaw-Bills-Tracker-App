import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../domain/entities/bill_filter.dart';
import '../../domain/entities/bill_sort.dart';
import '../../domain/entities/bill_status.dart';

/// The bills list's current search, filters and order.
///
/// One notifier for all of it rather than a provider per filter. They are read
/// together on every rebuild and written one at a time, so separate providers
/// would mean the screen watching six things to answer one question — and
/// "how many filters are applied" would have to be assembled at the call site.
///
/// Not persisted. A filter is a question the user is asking right now, and coming
/// back tomorrow to a list still narrowed to one category looks like missing
/// bills. The sort could reasonably be remembered; that is a settings decision,
/// not this one.
class BillFilterController extends Notifier<BillFilter> {
  @override
  BillFilter build() => BillFilter.none;

  /// The search text, as typed.
  ///
  /// Not debounced. Filtering happens against a list already in memory, so there
  /// is no request to delay — a debounce here would only add lag to a keystroke
  /// that costs nothing.
  void search(String query) => state = state.copyWith(query: query);

  void setStatuses(Set<BillStatus> statuses) =>
      state = state.copyWith(statuses: statuses);

  void setCategories(Set<String> categoryIds) =>
      state = state.copyWith(categoryIds: categoryIds);

  /// Sets or clears the due-date bounds together, because the pill sets them
  /// together — a range with one end cleared is a different range, not no range.
  void setDueRange({DateTime? from, DateTime? to}) =>
      state = from == null && to == null
      ? state.clearing(due: true)
      : state.clearing(due: true).copyWith(dueFrom: from, dueTo: to);

  void setAmountRange({Money? min, Money? max}) =>
      state = min == null && max == null
      ? state.clearing(amount: true)
      : state.clearing(amount: true).copyWith(minAmount: min, maxAmount: max);

  void setSort(BillSort sort) => state = state.copyWith(sort: sort);

  /// Clears every filter but keeps the order. Reordering is a preference, and
  /// "Clear filters" silently re-sorting the list would be a surprise.
  void clear() => state = state.cleared();
}

final NotifierProvider<BillFilterController, BillFilter> billFilterProvider =
    NotifierProvider<BillFilterController, BillFilter>(
      BillFilterController.new,
    );
