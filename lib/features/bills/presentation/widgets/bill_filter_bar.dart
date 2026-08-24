import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/widgets/app_filter_pill.dart';
import '../../../../core/presentation/widgets/app_search_field.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../domain/entities/bill_filter.dart';
import '../../domain/entities/bill_status.dart';
import '../controllers/bill_filter_controller.dart';
import 'bill_filter_sheets.dart';
import 'bill_status_display.dart';

/// Search, then a scrolling row of filter pills.
///
/// The arrangement the reference design's search screen uses, and what
/// `AppSearchField` and `AppFilterPill` were built for — both had sat unused in
/// the design system since it was written, with `AppFilterPill`'s own doc naming
/// `Category ▾`, `Status ▾`, `Due date ▾` as its intended callers.
///
/// **Sort is not here.** It went to the app bar: it was the fifth pill of five,
/// which put it at x=594 on a 392dp screen — permanently off the end of the row
/// and reachable only by scrolling to something the user could not see. It also
/// never fitted the row's meaning, since reordering a list narrows nothing.
///
/// **Pills rather than one Filters sheet.** Five filters behind a single button
/// means the row can never show what is applied, and the state of a filtered list
/// has to be inferred from a badge. Each pill shows its own value and turns green
/// when it is narrowing anything, so the row reads as the answer to "why am I
/// looking at four bills".
///
/// The pills scroll horizontally rather than wrapping. A wrapping row changes
/// height as values get longer, and the list under it jumps.
class BillFilterBar extends ConsumerStatefulWidget {
  const BillFilterBar({required this.today, super.key});

  /// Today in the *user's* zone, taken from a bill row rather than the device.
  ///
  /// The date presets are relative, and computing "this month" from a phone with
  /// the wrong date set would disagree with the statuses on the same screen. See
  /// [BillWithStatus.today].
  final DateTime today;

  @override
  ConsumerState<BillFilterBar> createState() => _BillFilterBarState();
}

class _BillFilterBarState extends ConsumerState<BillFilterBar> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BillFilter filter = ref.watch(billFilterProvider);

    // Kept in step with the controller, so "Clear filters" empties the box.
    // Guarded, because assigning unconditionally would fight the user's cursor
    // on every rebuild while they type.
    if (_search.text != filter.query) {
      _search.text = filter.query;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppSearchField(
          hint: 'Search bills',
          controller: _search,
          onChanged: (String value) =>
              ref.read(billFilterProvider.notifier).search(value),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Bleeds to the screen edge so the last pill does not look clipped
          // mid-scroll, then pads back in to line up with the cards.
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Row(
            children: <Widget>[
              AppFilterPill(
                label: _statusLabel(filter),
                isApplied: filter.statuses.isNotEmpty,
                onPressed: _pickStatuses,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppFilterPill(
                label: _categoryLabel(filter),
                isApplied: filter.categoryIds.isNotEmpty,
                onPressed: _pickCategories,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppFilterPill(
                label: _dueLabel(filter),
                isApplied: filter.dueFrom != null || filter.dueTo != null,
                onPressed: _pickDueRange,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppFilterPill(
                label: _amountLabel(filter),
                isApplied: filter.minAmount != null || filter.maxAmount != null,
                onPressed: _pickAmountRange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Labels. Each names the filter when nothing is chosen and the value when one
  // is — 'Status' becomes 'Overdue', or '2 statuses' when a list would not fit.
  // ---------------------------------------------------------------------------

  String _statusLabel(BillFilter filter) => switch (filter.statuses.length) {
    0 => 'Status',
    1 => BillStatusDisplay.label(filter.statuses.first),
    final int count => '$count statuses',
  };

  String _categoryLabel(BillFilter filter) {
    if (filter.categoryIds.isEmpty) {
      return 'Category';
    }
    if (filter.categoryIds.length > 1) {
      return '${filter.categoryIds.length} categories';
    }

    final String id = filter.categoryIds.first;

    return switch (ref.watch(categoriesProvider)) {
      AsyncData<List<Category>>(value: final List<Category> all) =>
        all.where((Category c) => c.id == id).firstOrNull?.name ?? 'Category',
      // The name has not arrived yet. '1 category' is true either way, which
      // beats showing 'Category' over a list that is clearly filtered.
      _ => '1 category',
    };
  }

  String _dueLabel(BillFilter filter) {
    final DateTime? from = filter.dueFrom;
    final DateTime? to = filter.dueTo;

    if (from == null && to == null) {
      return 'Due';
    }
    if (_preset(filter) case final _DuePreset preset) {
      return preset.label;
    }

    final DateFormat format = DateFormat.MMMd();

    return switch ((from, to)) {
      (final DateTime a, final DateTime b) =>
        '${format.format(a)} – ${format.format(b)}',
      (final DateTime a, null) => 'After ${format.format(a)}',
      (null, final DateTime b) => 'Before ${format.format(b)}',
      _ => 'Due',
    };
  }

  String _amountLabel(BillFilter filter) {
    final Money? min = filter.minAmount;
    final Money? max = filter.maxAmount;

    return switch ((min, max)) {
      (final Money a, final Money b) => '${a.format()} – ${b.format()}',
      (final Money a, null) => 'Over ${a.format()}',
      (null, final Money b) => 'Under ${b.format()}',
      _ => 'Amount',
    };
  }

  /// Which preset produced the current range, if any, so the pill can say
  /// "This month" rather than "Aug 1 – Aug 31".
  _DuePreset? _preset(BillFilter filter) {
    for (final _DuePreset preset in _DuePreset.values) {
      if (preset == _DuePreset.custom) {
        continue;
      }

      final (DateTime?, DateTime?) range = preset.range(widget.today);
      if (range.$1 == filter.dueFrom && range.$2 == filter.dueTo) {
        return preset;
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Pickers.
  // ---------------------------------------------------------------------------

  Future<void> _pickStatuses() async {
    final Set<BillStatus>? chosen = await showFilterMultiSelect<BillStatus>(
      context: context,
      title: 'Status',
      // Every status the view can produce, in the order they need attention.
      // Archived is on the list rather than a separate switch in the app bar:
      // "show me the ones I put away" is a filter, and having it in two places
      // was two controls for one question.
      options: const <BillStatus>[
        BillStatus.overdue,
        BillStatus.dueToday,
        BillStatus.dueSoon,
        BillStatus.upcoming,
        BillStatus.partiallyPaid,
        BillStatus.paid,
        BillStatus.archived,
      ].map(_statusOption).toList(),
      selected: ref.read(billFilterProvider).statuses,
    );

    if (chosen != null) {
      ref.read(billFilterProvider.notifier).setStatuses(chosen);
    }
  }

  static FilterOption<BillStatus> _statusOption(BillStatus status) =>
      FilterOption<BillStatus>(
        value: status,
        label: BillStatusDisplay.label(status),
        icon: switch (status) {
          BillStatus.overdue => Icons.error_outline_rounded,
          BillStatus.dueToday => Icons.today_rounded,
          BillStatus.dueSoon => Icons.event_outlined,
          BillStatus.upcoming => Icons.schedule_rounded,
          BillStatus.partiallyPaid => Icons.donut_large_rounded,
          BillStatus.paid => Icons.check_circle_outline_rounded,
          BillStatus.archived => Icons.inventory_2_outlined,
        },
      );

  Future<void> _pickCategories() async {
    final List<Category> categories =
        ref.read(categoriesProvider).value ?? const <Category>[];

    if (categories.isEmpty) {
      // Nothing to choose from. An empty sheet is worse than no sheet — the same
      // call the add-bill form's category field makes.
      return;
    }

    final Set<String>? chosen = await showFilterMultiSelect<String>(
      context: context,
      title: 'Category',
      options: categories
          .map((Category c) => FilterOption<String>(value: c.id, label: c.name))
          .toList(),
      selected: ref.read(billFilterProvider).categoryIds,
    );

    if (chosen != null) {
      ref.read(billFilterProvider.notifier).setCategories(chosen);
    }
  }

  Future<void> _pickDueRange() async {
    final _DuePreset? preset = await showFilterSingleSelect<_DuePreset>(
      context: context,
      title: 'Due date',
      options: _DuePreset.values
          .map(
            (_DuePreset p) => FilterOption<_DuePreset>(
              value: p,
              label: p.label,
              icon: p.icon,
            ),
          )
          .toList(),
      // Null is not a valid selection, so nothing shows as chosen when there is
      // no range. `_preset` returns null for a custom one too, which is right —
      // 'Custom range' is an action, not a state.
      selected: _preset(ref.read(billFilterProvider)) ?? _DuePreset.custom,
    );

    if (preset == null || !mounted) {
      return;
    }

    if (preset == _DuePreset.custom) {
      await _pickCustomDueRange();

      return;
    }

    final (DateTime? from, DateTime? to) = preset.range(widget.today);
    ref.read(billFilterProvider.notifier).setDueRange(from: from, to: to);
  }

  Future<void> _pickCustomDueRange() async {
    final BillFilter filter = ref.read(billFilterProvider);

    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      // Wide enough for a bill entered years ago and a recurrence years out.
      firstDate: DateTime(widget.today.year - 5),
      lastDate: DateTime(widget.today.year + 5, 12, 31),
      currentDate: widget.today,
      initialDateRange: switch ((filter.dueFrom, filter.dueTo)) {
        (final DateTime a, final DateTime b) => DateTimeRange(start: a, end: b),
        _ => null,
      },
      helpText: 'Bills due between',
    );

    if (range != null) {
      ref
          .read(billFilterProvider.notifier)
          .setDueRange(from: range.start, to: range.end);
    }
  }

  Future<void> _pickAmountRange() async {
    final BillFilter filter = ref.read(billFilterProvider);

    final AmountRange? range = await showAmountRangeSheet(
      context: context,
      current: AmountRange(min: filter.minAmount, max: filter.maxAmount),
    );

    if (range != null) {
      ref
          .read(billFilterProvider.notifier)
          .setAmountRange(min: range.min, max: range.max);
    }
  }
}

/// The ready-made due-date ranges.
///
/// Presets rather than only a date picker, because "this month" is the question
/// people actually ask and picking two dates to express it is four taps. The
/// custom range is still there for everything else.
enum _DuePreset {
  overdue('Past due', Icons.history_rounded),
  next7('Next 7 days', Icons.date_range_rounded),
  next30('Next 30 days', Icons.calendar_month_rounded),
  thisMonth('This month', Icons.event_note_rounded),
  custom('Custom range', Icons.edit_calendar_rounded);

  const _DuePreset(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The bounds this preset means, relative to the user's today.
  ///
  /// Returns `(null, null)` for [custom], which has no fixed range — the caller
  /// opens the date picker instead of applying this.
  (DateTime?, DateTime?) range(DateTime today) {
    final DateTime start = DateTime(today.year, today.month, today.day);

    return switch (this) {
      // Yesterday and earlier. Today is not past due — it is the last day it can
      // be paid on time, which is what `due_today` exists to say.
      _DuePreset.overdue => (null, start.subtract(const Duration(days: 1))),
      _DuePreset.next7 => (start, start.add(const Duration(days: 7))),
      _DuePreset.next30 => (start, start.add(const Duration(days: 30))),
      // Day 0 of next month is the last day of this one, which avoids caring how
      // long the month is or whether it is a leap year.
      _DuePreset.thisMonth => (
        DateTime(today.year, today.month),
        DateTime(today.year, today.month + 1, 0),
      ),
      _DuePreset.custom => (null, null),
    };
  }
}
