import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/account_setup.dart';

/// Which days before a due date to be reminded on.
///
/// A row of toggles rather than a multi-select dropdown: there are four choices,
/// more than one is normally on, and seeing all four at once is the difference
/// between understanding the setting and guessing at it.
///
/// Not [AppFilterPill], despite looking similar. That pill means "this narrows a
/// list", and reusing it for a setting would make two unrelated things share a
/// visual language — the sort of reuse that saves thirty lines and costs a
/// design system.
class ReminderDaySelector extends StatelessWidget {
  const ReminderDaySelector({
    required this.choices,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
    super.key,
  });

  /// Offsets to offer, furthest first.
  final List<int> choices;

  /// Currently on.
  final List<int> selected;

  final ValueChanged<int> onToggle;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool atLimit = selected.length >= AccountSetup.maxDaysBefore;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final int days in choices)
          _DayChip(
            label: _labelFor(days),
            isSelected: selected.contains(days),
            // A chip that cannot be turned on is disabled rather than silently
            // inert. The last remaining chip stays enabled, because tapping it
            // and having nothing happen is clearer than a chip that looks broken
            // — turning reminders off entirely is what the switch above is for.
            enabled: enabled && (selected.contains(days) || !atLimit),
            onPressed: () => onToggle(days),
          ),
      ],
    );
  }

  /// `0` is the due date itself, which "0 days before" says badly.
  static String _labelFor(int days) => switch (days) {
    0 => 'On the day',
    1 => '1 day before',
    _ => '$days days before',
  };
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color background = switch ((enabled, isSelected)) {
      (false, _) => colors.disabled,
      (true, true) => colors.primarySoft,
      (true, false) => colors.surfaceMuted,
    };

    final Color foreground = switch ((enabled, isSelected)) {
      (false, _) => colors.onDisabled,
      (true, true) => colors.primaryText,
      (true, false) => colors.textSecondary,
    };

    return Semantics(
      // Announced as a checkbox, which is what it behaves like. Without this a
      // screen reader reads only the label and gives no way to know it is on.
      checked: isSelected,
      enabled: enabled,
      button: true,
      child: Material(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.pill)),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.pill)),
          child: Container(
            // 48 tall to stay above the minimum tap target even though the chip
            // reads as a small control.
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.sm),
                // Flexible, not a bare Text: `Wrap` bounds the chip's width to
                // the row it sits in, but a Row with MainAxisSize.min still hands
                // its children their natural width. At 2x text "3 days before"
                // is wider than a small phone, and the chip ran 161 pixels off
                // the edge. Wrapping to a second line inside the chip is the
                // right answer — the Container grows, since 48 is a minimum.
                Flexible(
                  child: Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
