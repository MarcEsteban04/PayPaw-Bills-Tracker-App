import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/reminder_time.dart';

/// The time of day reminders arrive.
///
/// A tappable field over the platform time picker, like `DueDateField` is over
/// the date one. Built for onboarding and now shared with the reminder settings
/// screen — the two ask the identical question, and two spellings of it would
/// drift the moment either gained a detail.
class ReminderTimeField extends StatelessWidget {
  const ReminderTimeField({
    required this.time,
    required this.enabled,
    required this.onChanged,
    this.label = 'At what time',
    super.key,
  });

  final ReminderTime time;
  final bool enabled;
  final ValueChanged<ReminderTime> onChanged;

  /// The heading above the field. Onboarding asks "at what time"; a per-bill
  /// sheet wants to say which time it means.
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Formatted through the framework's localisations rather than by hand, so a
    // device set to 24-hour time shows 21:00 and not 9:00 PM.
    final String formatted = TimeOfDay(
      hour: time.hour,
      minute: time.minute,
    ).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'At what time',
          style: textTheme.labelLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: enabled ? colors.surfaceInput : colors.disabled,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: enabled ? colors.textSecondary : colors.onDisabled,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      formatted,
                      style: textTheme.bodyLarge?.copyWith(
                        color: enabled ? colors.textPrimary : colors.onDisabled,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled ? colors.textSecondary : colors.onDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: 'Reminder time',
    );

    if (picked != null) {
      onChanged(ReminderTime(hour: picked.hour, minute: picked.minute));
    }
  }
}
