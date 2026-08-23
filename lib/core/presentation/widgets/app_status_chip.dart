import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

export '../../theme/app_palette.dart' show AppStatusTone;

/// A small coloured badge stating the state of something.
///
/// Colour alone is never the only signal: the label always spells the state out,
/// so the chip still works for a colour-blind user or in a screenshot printed in
/// grey.
///
/// The tone's two colours come from the active palette rather than from the
/// [AppStatusTone] itself. They used to live on the enum as constants, which is
/// exactly what made a dark theme impossible: an enum value cannot know which
/// theme is showing.
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
    final AppPalette palette = context.colors;
    final Color foreground = palette.statusText(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.statusTint(tone),
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
              Icon(iconData, size: 12, color: foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
