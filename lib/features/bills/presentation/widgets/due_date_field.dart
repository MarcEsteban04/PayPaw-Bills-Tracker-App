import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validation/bill_validators.dart';

/// The date a bill is due, opened through the platform date picker.
///
/// A tappable field rather than a text input. A typed date needs parsing, a
/// format to teach, and an error message for "13/13/2026"; a picker cannot
/// produce an invalid date at all. The cost is that it must show its own
/// validation error, which a `TextFormField` would have done for free — hence
/// [errorText].
class DueDateField extends StatelessWidget {
  const DueDateField({
    required this.value,
    required this.today,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    super.key,
  });

  /// Null until the user picks one.
  final DateTime? value;

  /// What "today" is, passed in rather than read from the clock, so the bounds
  /// this field offers are the same ones [BillValidators.dueDate] enforces.
  final DateTime today;

  final ValueChanged<DateTime> onChanged;

  final bool enabled;

  /// Shown under the field, styled like a `TextFormField`'s error.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Due date',
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
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
                      value == null ? 'Pick a date' : _format(value!),
                      style: textTheme.bodyLarge?.copyWith(
                        // The placeholder is a hint, not a value, and has to look
                        // like one — otherwise an unfilled field reads as filled.
                        color: switch ((enabled, value)) {
                          (false, _) => colors.onDisabled,
                          (true, null) => colors.textTertiary,
                          (true, _) => colors.textPrimary,
                        },
                      ),
                    ),
                  ),
                  if (value != null)
                    Text(
                      _relative(value!, today),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
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
      // The same bounds the validator enforces, taken from the same constants.
      // A picker that offers a date the form then rejects is a picker that lies.
      firstDate: DateTime(today.year - BillValidators.maxYearsInPast),
      lastDate: DateTime(today.year + BillValidators.maxYearsInFuture, 12, 31),
      helpText: 'When is it due?',
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
  static String _relative(DateTime dueOn, DateTime today) {
    final int days = DateTime(
      dueOn.year,
      dueOn.month,
      dueOn.day,
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
