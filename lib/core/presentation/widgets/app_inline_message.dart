import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// A short message shown inside a screen, in the tone of its meaning.
///
/// For a failure that belongs *next to* what caused it — a form that was
/// rejected, a field-level warning — rather than in place of the whole screen.
/// `AppErrorState` replaces a screen; this sits in one.
///
/// It reuses `AppStatusTone`'s tint-and-text pairs, so the colours are the same
/// accessible combinations status chips use, in either theme.
class AppInlineMessage extends StatelessWidget {
  const AppInlineMessage({
    required this.message,
    required this.tone,
    this.icon,
    super.key,
  });

  /// What happened, in a sentence the user can act on.
  final String message;

  /// Which colour pair to use.
  final AppStatusTone tone;

  /// Optional leading icon. A second, non-colour cue.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.colors;
    final Color foreground = palette.statusText(tone);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.statusTint(tone),
        borderRadius: AppRadii.input,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon case final IconData iconData) ...<Widget>[
              Icon(iconData, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.sm),
            ],
            // Flexible so a long backend message wraps instead of overflowing.
            Flexible(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
