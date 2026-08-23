import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// What a status chip is saying.
///
/// Presentation-level on purpose. It is not a bill status: the domain has not
/// been modelled yet, and when it is, a bill's status maps *onto* a tone rather
/// than being one. Subscriptions and debts will map onto the same tones.
enum AppStatusTone {
  /// Settled, on track, done.
  paid(background: AppColors.paidTint, foreground: AppColors.paidText),

  /// Approaching its date but not yet late.
  dueSoon(background: AppColors.dueSoonTint, foreground: AppColors.dueSoonText),

  /// Past its date.
  overdue(background: AppColors.overdueTint, foreground: AppColors.overdueText),

  /// Worth noticing, but not good or bad — 'Auto-pay', 'Shared'.
  info(background: AppColors.infoTint, foreground: AppColors.infoText),

  /// No judgement — 'Draft', 'Archived'.
  neutral(
    background: AppColors.surfaceMuted,
    foreground: AppColors.textSecondary,
  );

  const AppStatusTone({required this.background, required this.foreground});

  /// Pale wash behind the label.
  final Color background;

  /// Label colour. Paired with [background] to clear 4.5:1 — never mix a tone's
  /// background with another tone's foreground.
  final Color foreground;
}

/// A small coloured badge stating the state of something.
///
/// Colour alone is never the only signal: the label always spells the state out,
/// so the chip still works for a colour-blind user or in a screenshot printed in
/// grey.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  /// The state, in words. 'Overdue', 'Paid', 'Due in 3 days'.
  final String label;

  /// Which colour pair to use.
  final AppStatusTone tone;

  /// Optional leading icon, for a second non-colour cue.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: AppRadii.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final IconData iconData) ...<Widget>[
              Icon(iconData, size: 12, color: tone.foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: tone.foreground),
            ),
          ],
        ),
      ),
    );
  }
}
