import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// The filter pills from the reference design's search screen — `Job Type ▾`,
/// which for PayPaw becomes `Category ▾`, `Status ▾`, `Due date ▾`.
///
/// Tapping one opens its own picker; the pill itself only shows the current
/// choice. When a filter is applied the pill switches to the green tint, so the
/// row shows at a glance how narrow the current view is.
///
/// **On tap targets:** the pill is 36dp tall to match the reference, which is
/// below Material's 48dp minimum. Rather than make it visually taller, the
/// tappable area is padded out to 48dp around it. In a horizontal row that costs
/// nothing, and the pill stays the size the design asks for.
class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    required this.label,
    required this.onPressed,
    this.isApplied = false,
    this.showCaret = true,
    super.key,
  });

  /// The filter, and its value when one is set: 'Category' or 'Electricity'.
  final String label;

  final VoidCallback onPressed;

  /// Whether this filter is currently narrowing the results.
  final bool isApplied;

  /// Whether to show the disclosure caret. Off for a pill that toggles rather
  /// than opening a picker.
  final bool showCaret;

  /// Visual height, from the reference.
  static const double _pillHeight = 36;

  /// Minimum accessible tap height.
  static const double _tapHeight = 48;

  @override
  Widget build(BuildContext context) {
    final Color foreground = isApplied
        ? context.colors.primaryText
        : context.colors.textSecondary;

    return SizedBox(
      height: _tapHeight,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadii.chip,
        child: Center(
          child: Container(
            height: _pillHeight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: isApplied
                  ? context.colors.primarySoft
                  : context.colors.surfaceMuted,
              borderRadius: AppRadii.chip,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: isApplied ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (showCaret) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: foreground,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
