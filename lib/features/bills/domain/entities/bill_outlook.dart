import 'package:meta/meta.dart';

import '../../../../core/domain/money.dart';
import 'bill_with_status.dart';

/// One slice of the outstanding total.
@immutable
class CategorySlice {
  const CategorySlice({
    required this.categoryId,
    required this.outstanding,
    required this.share,
    required this.billCount,
  });

  /// Null for bills with no category, which is a real answer and not a gap —
  /// "uncategorised" is where a surprising amount of money usually is.
  final String? categoryId;

  final Money outstanding;

  /// 0 to 1 of the whole.
  final double share;

  final int billCount;

  /// Whether this is the merged tail rather than a single category.
  bool get isOther => categoryId == otherId;

  /// The sentinel for the merged remainder. Not a real category id, and nothing
  /// looks it up — [isOther] is the question callers ask.
  static const String otherId = '__other__';
}

/// What one month owes.
@immutable
class MonthlyDue {
  const MonthlyDue({required this.month, required this.outstanding});

  /// The first of the month, at midnight.
  final DateTime month;

  final Money outstanding;
}

/// The forward-looking view of a set of bills.
///
/// Separate from `BillTotals`, which answers "where do I stand". This answers
/// "where is it going and when" — the two questions a dashboard chart is for, and
/// neither of them is a sum the summary card already shows.
///
/// **Only outstanding money counts.** A settled bill is not a claim on anything,
/// and an archived one is a claim the user has waved off, so both are absent from
/// every figure here.
@immutable
class BillOutlook {
  const BillOutlook({
    required this.byCategory,
    required this.byMonth,
    required this.dueThisMonth,
    required this.dueNextMonth,
    required this.total,
  });

  factory BillOutlook.of(
    List<BillWithStatus> bills, {
    required DateTime today,
    int months = 6,
    int topCategories = 4,
  }) {
    final String currency = bills.isEmpty
        ? 'PHP'
        : bills.first.outstanding.currency;
    final Money zero = Money(minorUnits: 0, currency: currency);

    final List<BillWithStatus> owing = bills
        .where(
          (BillWithStatus b) =>
              !b.bill.isArchived && (b.status?.isOutstanding ?? false),
        )
        .toList();

    final Map<String?, Money> perCategory = <String?, Money>{};
    final Map<String?, int> perCategoryCount = <String?, int>{};
    final Map<int, Money> perMonth = <int, Money>{};
    Money total = zero;

    final int firstBucket = _monthIndex(today);
    final int lastBucket = firstBucket + months - 1;

    for (final BillWithStatus bill in owing) {
      total += bill.outstanding;

      perCategory.update(
        bill.bill.categoryId,
        (Money running) => running + bill.outstanding,
        ifAbsent: () => bill.outstanding,
      );
      perCategoryCount.update(
        bill.bill.categoryId,
        (int running) => running + 1,
        ifAbsent: () => 1,
      );

      // Anything due before this month lands in the current bucket. It is still
      // owed *now*, and a chart of what is ahead that quietly drops the arrears
      // understates the very month they have to be paid in.
      final int bucket = _monthIndex(bill.bill.dueOn)
          .clamp(firstBucket, lastBucket);

      perMonth.update(
        bucket,
        (Money running) => running + bill.outstanding,
        ifAbsent: () => bill.outstanding,
      );
    }

    return BillOutlook(
      byCategory: _slices(
        perCategory,
        perCategoryCount,
        total: total,
        zero: zero,
        keep: topCategories,
      ),
      byMonth: <MonthlyDue>[
        for (int i = firstBucket; i <= lastBucket; i++)
          MonthlyDue(month: _monthOf(i), outstanding: perMonth[i] ?? zero),
      ],
      dueThisMonth: perMonth[firstBucket] ?? zero,
      dueNextMonth: perMonth[firstBucket + 1] ?? zero,
      total: total,
    );
  }

  /// Largest first, with the tail merged.
  final List<CategorySlice> byCategory;

  /// One entry per month, starting with the current one. Always full length, so
  /// a chart's axis does not change shape as bills move.
  final List<MonthlyDue> byMonth;

  final Money dueThisMonth;
  final Money dueNextMonth;

  /// What every slice adds up to. The same figure as `BillTotals.outstanding`;
  /// carried here so a chart does not need both objects to work out a share.
  final Money total;

  bool get hasAnything => total.minorUnits > 0;

  /// The largest single month in [byMonth], for scaling a chart's bars.
  ///
  /// Zero when nothing is owed, which a caller has to handle rather than divide
  /// by.
  Money get busiestMonth => byMonth.fold(
    Money(minorUnits: 0, currency: total.currency),
    (Money largest, MonthlyDue month) =>
        month.outstanding > largest ? month.outstanding : largest,
  );

  /// Sorted, trimmed and totalled into slices.
  ///
  /// Only [keep] categories survive as themselves; the rest are merged. Thirteen
  /// slices is a paint chart, not a chart — and the answer to "where is my money
  /// going" is the top few, with the remainder named honestly rather than drawn
  /// as a dozen slivers.
  static List<CategorySlice> _slices(
    Map<String?, Money> amounts,
    Map<String?, int> counts, {
    required Money total,
    required Money zero,
    required int keep,
  }) {
    if (total.minorUnits <= 0) {
      return const <CategorySlice>[];
    }

    final List<MapEntry<String?, Money>> sorted = amounts.entries.toList()
      ..sort(
        (MapEntry<String?, Money> a, MapEntry<String?, Money> b) =>
            b.value.compareTo(a.value),
      );

    double shareOf(Money amount) => amount.minorUnits / total.minorUnits;

    final List<CategorySlice> slices = <CategorySlice>[
      for (final MapEntry<String?, Money> entry in sorted.take(keep))
        CategorySlice(
          categoryId: entry.key,
          outstanding: entry.value,
          share: shareOf(entry.value),
          billCount: counts[entry.key] ?? 0,
        ),
    ];

    if (sorted.length <= keep) {
      return slices;
    }

    Money rest = zero;
    int restCount = 0;
    for (final MapEntry<String?, Money> entry in sorted.skip(keep)) {
      rest += entry.value;
      restCount += counts[entry.key] ?? 0;
    }

    return <CategorySlice>[
      ...slices,
      CategorySlice(
        categoryId: CategorySlice.otherId,
        outstanding: rest,
        share: shareOf(rest),
        billCount: restCount,
      ),
    ];
  }

  /// Months since year zero, so two dates can be bucketed and compared as ints.
  static int _monthIndex(DateTime date) => date.year * 12 + (date.month - 1);

  static DateTime _monthOf(int index) => DateTime(index ~/ 12, index % 12 + 1);
}
