import 'package:flutter/material.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// One choice in a picker sheet.
@immutable
class FilterOption<T> {
  const FilterOption({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Picks any number of options. Returns the chosen set, or null if dismissed.
///
/// One sheet shared by status and category rather than one each. They differ in
/// nothing but their options — and a sheet built twice is a sheet where the
/// second copy quietly loses the "Clear" button.
///
/// An empty result means "no filter", not "match nothing". That is the rule
/// `BillFilter` follows for an empty set, and the two have to agree or the pill
/// will read "None" over a list showing everything.
Future<Set<T>?> showFilterMultiSelect<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  required Set<T> selected,
}) => showAppBottomSheet<Set<T>>(
  context: context,
  title: title,
  child: _MultiSelect<T>(options: options, initial: selected),
);

/// Picks exactly one option. Returns it, or null if dismissed.
Future<T?> showFilterSingleSelect<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  required T selected,
}) => showAppBottomSheet<T>(
  context: context,
  title: title,
  child: _SingleSelect<T>(options: options, selected: selected),
);

class _MultiSelect<T> extends StatefulWidget {
  const _MultiSelect({required this.options, required this.initial});

  final List<FilterOption<T>> options;
  final Set<T> initial;

  @override
  State<_MultiSelect<T>> createState() => _MultiSelectState<T>();
}

class _MultiSelectState<T> extends State<_MultiSelect<T>> {
  late final Set<T> _selected = Set<T>.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Flexible, so a long list scrolls inside the sheet instead of pushing
        // the buttons off the bottom. The same fix the category picker needed.
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.options.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final FilterOption<T> option = widget.options[index];

              return _OptionRow(
                label: option.label,
                icon: option.icon,
                isSelected: _selected.contains(option.value),
                isMultiple: true,
                onTap: () => setState(() {
                  if (!_selected.remove(option.value)) {
                    _selected.add(option.value);
                  }
                }),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: AppSecondaryButton(
                label: 'Clear',
                // An empty set, not null. Null means "dismissed, change nothing",
                // and this is a deliberate clear.
                onPressed: () => Navigator.of(context).pop(<T>{}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(
                label: 'Apply',
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SingleSelect<T> extends StatelessWidget {
  const _SingleSelect({required this.options, required this.selected});

  final List<FilterOption<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    // No Apply button. With one choice the tap *is* the decision, and a second
    // confirmation would be a step that cannot change the outcome.
    //
    // No Flexible either, unlike the multi-select's inner list. This *is* the
    // sheet's child, and `showAppBottomSheet` already wraps that in one — two
    // Flexibles writing FlexParentData to the same RenderObject is an assertion,
    // not a layout. The multi-select gets away with it because its Flexible sits
    // inside a Column of its own.
    return ListView.separated(
      shrinkWrap: true,
      itemCount: options.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) {
        final FilterOption<T> option = options[index];

        return _OptionRow(
          label: option.label,
          icon: option.icon,
          isSelected: option.value == selected,
          isMultiple: false,
          onTap: () => Navigator.of(context).pop(option.value),
        );
      },
    );
  }
}

/// A row in either sheet: an optional icon, a label, and the mark of its state.
///
/// A checkbox for many and a tick for one, because the shape of the control is
/// what tells the user whether choosing this un-chooses the last one.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isMultiple,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool isMultiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.primarySoft : colors.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              // 48dp of height at the default text size, without hard-coding it.
              vertical: AppSpacing.md + 2,
            ),
            child: Row(
              children: <Widget>[
                if (icon case final IconData glyph) ...<Widget>[
                  Icon(
                    glyph,
                    size: 18,
                    color: isSelected
                        ? colors.primaryText
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? colors.primaryText
                          : colors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  isMultiple
                      ? (isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                      : (isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined),
                  size: 20,
                  color: isSelected ? colors.primary : colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The two ends of an amount range.
@immutable
class AmountRange {
  const AmountRange({this.min, this.max});

  final Money? min;
  final Money? max;

  bool get isEmpty => min == null && max == null;
}

/// Asks for an amount range. Returns it, or null if dismissed.
///
/// Its own sheet rather than a list of preset brackets. "Over ₱1,000" and "under
/// ₱500" are guesses about somebody else's bills — the amounts that matter depend
/// entirely on whose bills they are.
Future<AmountRange?> showAmountRangeSheet({
  required BuildContext context,
  required AmountRange current,
}) => showAppBottomSheet<AmountRange>(
  context: context,
  title: 'Amount',
  child: _AmountRangePicker(current: current),
);

class _AmountRangePicker extends StatefulWidget {
  const _AmountRangePicker({required this.current});

  final AmountRange current;

  @override
  State<_AmountRangePicker> createState() => _AmountRangePickerState();
}

class _AmountRangePickerState extends State<_AmountRangePicker> {
  late final TextEditingController _min = TextEditingController(
    text: widget.current.min?.formatBare() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.current.max?.formatBare() ?? '',
  );

  String? _error;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _apply() {
    final Money? min = Money.tryParse(_min.text);
    final Money? max = Money.tryParse(_max.text);

    // A backwards range matches nothing, and an empty list with no explanation
    // reads as a bug in the app rather than a typo in the field.
    if (min != null && max != null && min > max) {
      setState(() => _error = 'The smallest cannot be more than the largest.');

      return;
    }

    Navigator.of(context).pop(AmountRange(min: min, max: max));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: AppAmountField(
                controller: _min,
                label: 'From',
                helperText: 'Leave blank for no minimum',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppAmountField(
                controller: _max,
                label: 'To',
                helperText: 'Leave blank for no maximum',
              ),
            ),
          ],
        ),
        if (_error case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.overdueText),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: AppSecondaryButton(
                label: 'Clear',
                onPressed: () => Navigator.of(context).pop(const AmountRange()),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(label: 'Apply', onPressed: _apply),
            ),
          ],
        ),
      ],
    );
  }
}
