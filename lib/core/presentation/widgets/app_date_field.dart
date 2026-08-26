import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// A date, chosen through the platform date picker.
///
/// A tappable field rather than a text input. A typed date needs parsing, a
/// format to teach, and an error message for "13/13/2026"; a picker cannot
/// produce an invalid date at all. The cost is that it must show its own
/// validation error, which a `TextFormField` would have done for free — hence
/// [errorText].
///
/// ## Why this is in core
///
/// It began as the bill form's due date field. Subscriptions need the same
/// control three times over — when it charges next, when the trial ends — and
/// the alternative was a second copy carrying the same relative-date wording,
/// the same error styling and the same picker bounds. The only parts that were
/// ever about bills are the label and the picker's title, so they are parameters.
class AppDateField extends StatelessWidget {
  const AppDateField({
    required this.label,
    required this.value,
    required this.today,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.helpText,
    this.placeholder = 'Pick a date',
    this.onCleared,
    this.enabled = true,
    this.errorText,
    super.key,
  });

  /// The field's own label, above the control. 'Due date', 'Trial ends'.
  final String label;

  /// Null until the user picks one.
  final DateTime? value;

  /// What "today" is, passed in rather than read from the clock, so the relative
  /// wording agrees with the statuses on the screen behind it.
  final DateTime today;

  final ValueChanged<DateTime> onChanged;

  /// The bounds the picker offers.
  ///
  /// Required rather than defaulted, because a picker that offers a date the
  /// form then rejects is a picker that lies — the caller owns the validator, so
  /// the caller owns these.
  final DateTime firstDate;
  final DateTime lastDate;

  /// The picker's own heading. 'When is it due?'
  final String? helpText;

  /// What the field reads when nothing is chosen.
  final String placeholder;

  /// Called when the user unsets the date.
  ///
  /// Null means the date is required, and no clear button is shown. A required
  /// field offering a way to empty itself is a field that invites the error it
  /// then complains about.
  final VoidCallback? onCleared;

  final bool enabled;

  /// Shown under the field, styled like a `TextFormField`'s error.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasError = errorText != null;
    final DateTime? chosen = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: enabled ? colors.surfaceInput : colors.disabled,
          borderRadius: AppRadii.input,
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: AppRadii.input,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                // The clear button brings its own padding, and stacking the two
                // pushes it away from the edge the thumb reaches for.
                chosen != null && onCleared != null
                    ? AppSpacing.xs
                    : AppSpacing.lg,
                AppSpacing.md,
              ),
              decoration: hasError
                  ? BoxDecoration(
                      borderRadius: AppRadii.input,
                      border: Border.all(color: colors.overdue),
                    )
                  : null,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 20,
                    color: enabled ? colors.textSecondary : colors.onDisabled,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      chosen == null ? placeholder : _format(chosen),
                      style: textTheme.bodyLarge?.copyWith(
                        // The placeholder is a hint, not a value, and has to look
                        // like one — otherwise an unfilled field reads as filled.
                        color: switch ((enabled, chosen)) {
                          (false, _) => colors.onDisabled,
                          (true, null) => colors.textTertiary,
                          (true, _) => colors.textPrimary,
                        },
                      ),
                    ),
                  ),
                  if (chosen != null)
                    Text(
                      _relative(chosen, today),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  if (chosen != null && onCleared != null)
                    IconButton(
                      onPressed: enabled ? onCleared : null,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: colors.textSecondary,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Clear $label',
                    ),
                ],
              ),
            ),
          ),
        ),
        if (errorText case final String message) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: colors.overdueText),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value ?? today,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  /// `Fri, 5 Sep 2026`. Through intl, so a device set to another locale gets its
  /// own order and month names.
  static String _format(DateTime date) => DateFormat.yMMMEd().format(date);

  /// The part a person actually reads: how soon.
  ///
  /// A date on its own makes the reader do the arithmetic, and the whole point of
  /// this app is not making them.
  static String _relative(DateTime date, DateTime today) {
    final int days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;

    return switch (days) {
      0 => 'today',
      1 => 'tomorrow',
      -1 => 'yesterday',
      < 0 => '${-days} days ago',
      _ => 'in $days days',
    };
  }
}
