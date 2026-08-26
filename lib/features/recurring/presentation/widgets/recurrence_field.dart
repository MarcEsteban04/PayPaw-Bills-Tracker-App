import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/recurrence.dart';
import 'recurrence_editor_sheet.dart';

/// A form field for "does this repeat, and how".
///
/// Reads as a row rather than an input, because the thing being set is a
/// paragraph — "Every 2 weeks on Friday" — and no text box holds that. Tapping it
/// opens [showRecurrenceEditor]; the field itself only shows the answer.
///
/// **Null is a real value here**, and the common one: most bills do not repeat.
/// The empty state says "Does not repeat" rather than being blank, so the field
/// answers the question even when nothing is set.
class RecurrenceField extends StatelessWidget {
  const RecurrenceField({
    required this.value,
    required this.today,
    required this.onChanged,
    this.startFrom,
    this.label = 'Repeat',
    this.emptyLabel = 'Does not repeat',
    this.enabled = true,
    super.key,
  });

  final Recurrence? value;

  /// Today in the user's own zone, for the editor's date pickers and its preview.
  /// Passed in rather than read from the device clock, so the preview cannot
  /// disagree with the statuses on the screen behind it.
  final DateTime today;

  /// Called with the new rule, or null when the user chose not to repeat.
  final ValueChanged<Recurrence?> onChanged;

  /// Where a new rule should start, when the screen already knows.
  ///
  /// The bill form passes its due date: "due 20 September, monthly" means the
  /// 20th, and a rule that opened on today's date instead disagreed with the
  /// field directly above it. Ignored once a rule exists — see the note in
  /// [showRecurrenceEditor].
  final DateTime? startFrom;

  /// What the field is called. 'Repeat' on a bill, 'Billing cycle' on a
  /// subscription.
  final String label;

  /// What it reads before a rule is set.
  ///
  /// A parameter because "Does not repeat" is a *true statement about a bill*
  /// and a false one about a subscription: the subscription form will not accept
  /// a draft without a cycle, so resting on the one answer it refuses would be
  /// the field lying about the form it is in.
  final String emptyLabel;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Recurrence? rule = value;

    return Semantics(
      button: true,
      label: label,
      value: rule?.describe() ?? emptyLabel,
      child: Material(
        color: colors.surfaceInput,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.repeat_rounded,
                  size: 20,
                  color: rule == null ? colors.textTertiary : colors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        rule?.describe() ?? emptyLabel,
                        style: textTheme.bodyLarge?.copyWith(
                          color: rule == null
                              ? colors.textSecondary
                              : colors.textPrimary,
                          fontWeight: rule == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final RecurrenceEditorResult? result = await showRecurrenceEditor(
      context: context,
      today: today,
      initial: value,
      startFrom: startFrom,
    );

    // Null means dismissed, which must leave an existing rule alone. Only an
    // explicit `RecurrenceCleared` removes one — see [RecurrenceEditorResult].
    switch (result) {
      case null:
        return;
      case RecurrenceChosen(recurrence: final Recurrence chosen):
        onChanged(chosen);
      case RecurrenceCleared():
        onChanged(null);
    }
  }
}
