import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'bill_sort.dart';
import 'bill_status.dart';
import 'bill_with_status.dart';

/// What the bills list is currently showing, and in what order.
///
/// ## Applied on the client, not in the query
///
/// One person's bills are tens of rows, occasionally hundreds. They are already
/// in memory, so filtering them here is instant and costs nothing — where a
/// server-side filter would be a round trip per keystroke, a loading state per
/// filter change, and a `PostgrestFilterBuilder` assembled from six optional
/// clauses. Revisit if a user ever has thousands of bills; that is the same
/// conversation as pagination, and neither is due yet.
///
/// ## In domain, not presentation
///
/// It looks like UI state, and it is — but [matches] is the rule for what belongs
/// in a result set, which is worth testing without pumping a widget. Nothing here
/// imports Flutter, which is why the date bounds are two [DateTime]s rather than a
/// `DateTimeRange`.
@immutable
class BillFilter {
  const BillFilter({
    this.query = '',
    this.statuses = const <BillStatus>{},
    this.categoryIds = const <String>{},
    this.dueFrom,
    this.dueTo,
    this.minAmount,
    this.maxAmount,
    this.sort = BillSort.dueSoonest,
  });

  /// Matched against the bill's name and payee, case-insensitively.
  final String query;

  /// Empty means every status *except archived*, not none.
  ///
  /// Two rules in one field, and the exception is the point: archiving means
  /// "stop showing me this", so the default view leaves those out however wide it
  /// otherwise is. Selecting Archived explicitly is how they come back.
  ///
  /// The alternative was leaving archived rows on the server and fetching them
  /// only when asked. That put the screen in a state it could not get out of: a
  /// user whose only bills are archived saw "No bills yet" — because the fetch
  /// had excluded them — with no filter bar rendered and so no way to ask for
  /// them. One rule here beats a fetch flag and a dead end.
  final Set<BillStatus> statuses;

  /// Empty means every category, including bills with no category at all.
  final Set<String> categoryIds;

  /// Inclusive bounds on the due date. Null for open-ended.
  final DateTime? dueFrom;
  final DateTime? dueTo;

  /// Inclusive bounds on the bill's full amount — not its outstanding balance.
  /// "Show me the bills over 5,000" is a question about the bill, not about how
  /// much of it is left to pay.
  final Money? minAmount;
  final Money? maxAmount;

  final BillSort sort;

  static const BillFilter none = BillFilter();

  /// Whether archived bills are being asked for.
  bool get includesArchived => statuses.contains(BillStatus.archived);

  /// Whether anything is narrowing the list.
  ///
  /// Sort is excluded on purpose. Reordering a list hides nothing, so counting it
  /// would put a "1 filter" badge on a screen showing everything, and would make
  /// "Clear filters" look like it had work to do when it did not.
  bool get isNarrowed =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      categoryIds.isNotEmpty ||
      dueFrom != null ||
      dueTo != null ||
      minAmount != null ||
      maxAmount != null;

  /// How many separate filters are applied, for the badge on the pill row.
  ///
  /// A range counts once however many of its two bounds are set — the user set
  /// one thing.
  int get narrowCount =>
      (query.trim().isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (categoryIds.isNotEmpty ? 1 : 0) +
      (dueFrom != null || dueTo != null ? 1 : 0) +
      (minAmount != null || maxAmount != null ? 1 : 0);

  /// Whether one bill belongs in the results.
  bool matches(BillWithStatus item) {
    if (!_matchesQuery(item)) {
      return false;
    }
    if (statuses.isEmpty) {
      // The default view. Everything the user has not put away — see the note on
      // [statuses] for why this is not simply "everything".
      if (item.bill.isArchived) {
        return false;
      }
    } else if (!statuses.contains(item.status)) {
      return false;
    }
    // A bill with no category is excluded once any category is chosen. It is not
    // in the chosen ones, and treating "uncategorised" as a wildcard would make
    // the pill's count disagree with the rows on screen.
    if (categoryIds.isNotEmpty &&
        !categoryIds.contains(item.bill.categoryId ?? '')) {
      return false;
    }
    if (!_matchesDue(item.bill.dueOn)) {
      return false;
    }
    if (minAmount case final Money floor when item.bill.amount < floor) {
      return false;
    }
    if (maxAmount case final Money ceiling when item.bill.amount > ceiling) {
      return false;
    }

    return true;
  }

  /// Filters and orders in one pass, so a screen has one thing to call.
  List<BillWithStatus> apply(List<BillWithStatus> bills) =>
      bills.where(matches).toList()..sort(_compare);

  bool _matchesQuery(BillWithStatus item) {
    final String needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }

    // Name and payee. Notes are deliberately not searched: they hold account
    // numbers and reminders to self, and matching them would surface a bill for
    // a reason the user cannot see anywhere on the row that came back.
    return item.bill.name.toLowerCase().contains(needle) ||
        (item.bill.payee?.toLowerCase().contains(needle) ?? false);
  }

  bool _matchesDue(DateTime dueOn) {
    final DateTime due = DateTime(dueOn.year, dueOn.month, dueOn.day);

    if (dueFrom case final DateTime from
        when due.isBefore(DateTime(from.year, from.month, from.day))) {
      return false;
    }
    if (dueTo case final DateTime to
        when due.isAfter(DateTime(to.year, to.month, to.day))) {
      return false;
    }

    return true;
  }

  /// Every order is total, with a documented tie-break.
  ///
  /// Without one, two bills that compare equal keep whatever order the fetch
  /// happened to return, and the list appears to shuffle itself between
  /// refreshes.
  int _compare(BillWithStatus a, BillWithStatus b) {
    final int primary = switch (sort) {
      BillSort.dueSoonest => a.bill.dueOn.compareTo(b.bill.dueOn),
      BillSort.dueLatest => b.bill.dueOn.compareTo(a.bill.dueOn),
      BillSort.amountHighest => b.bill.amount.compareTo(a.bill.amount),
      BillSort.amountLowest => a.bill.amount.compareTo(b.bill.amount),
      BillSort.nameAtoZ => _byName(a, b),
    };

    return primary != 0 ? primary : _byName(a, b);
  }

  static int _byName(BillWithStatus a, BillWithStatus b) =>
      a.bill.name.toLowerCase().compareTo(b.bill.name.toLowerCase());

  BillFilter copyWith({
    String? query,
    Set<BillStatus>? statuses,
    Set<String>? categoryIds,
    DateTime? dueFrom,
    DateTime? dueTo,
    Money? minAmount,
    Money? maxAmount,
    BillSort? sort,
  }) => BillFilter(
    query: query ?? this.query,
    statuses: statuses ?? this.statuses,
    categoryIds: categoryIds ?? this.categoryIds,
    dueFrom: dueFrom ?? this.dueFrom,
    dueTo: dueTo ?? this.dueTo,
    minAmount: minAmount ?? this.minAmount,
    maxAmount: maxAmount ?? this.maxAmount,
    sort: sort ?? this.sort,
  );

  /// Clears the nullable bounds, which [copyWith] cannot do.
  ///
  /// The same pattern as `Bill.clearing`: a `copyWith` where null means "leave it
  /// alone" has no way to say "set it to null", and every scheme for
  /// distinguishing the two is worse than a second method.
  BillFilter clearing({bool due = false, bool amount = false}) => BillFilter(
    query: query,
    statuses: statuses,
    categoryIds: categoryIds,
    dueFrom: due ? null : dueFrom,
    dueTo: due ? null : dueTo,
    minAmount: amount ? null : minAmount,
    maxAmount: amount ? null : maxAmount,
    sort: sort,
  );

  /// Everything cleared except the order, which is a preference rather than a
  /// filter — "Clear filters" should not silently re-sort the list.
  BillFilter cleared() => BillFilter(sort: sort);

  @override
  bool operator ==(Object other) =>
      other is BillFilter &&
      other.query == query &&
      setEquals(other.statuses, statuses) &&
      setEquals(other.categoryIds, categoryIds) &&
      other.dueFrom == dueFrom &&
      other.dueTo == dueTo &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(categoryIds),
    dueFrom,
    dueTo,
    minAmount,
    maxAmount,
    sort,
  );
}

/// Set equality, without pulling `package:flutter` into the domain layer for it.
///
/// `Set.==` is identity, so two filters holding equal-but-distinct sets would
/// compare unequal — which would make every provider watching this rebuild on
/// every filter object it saw.
bool setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
