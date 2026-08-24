import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';

/// One shortcut.
@immutable
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}

/// The row of shortcuts under the headline.
///
/// The reference design's "Quick Transaction" strip: circular buttons with labels
/// beneath, scrolling sideways.
///
/// **Only actions that work are here.** Sprint 37 is the quick-actions sprint and
/// its list includes marking a bill paid, adding a debt and adding a subscription
/// — none of which exist yet. A row of five where two do nothing teaches the user
/// that the row is decoration, and they stop reading it. Each one arrives when the
/// thing behind it does.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // A hair of padding, so a shadow or a focus ring is not clipped by the
      // scroll view's own bounds.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          for (final QuickAction action in actions) ...<Widget>[
            _ActionButton(action: action),
            if (action != actions.last) const SizedBox(width: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final QuickAction action;

  static const double _circle = 56;

  /// Wide enough for two short words without wrapping, which is what keeps the
  /// row's height from changing as actions are added.
  static const double _labelWidth = 72;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      button: true,
      label: action.label,
      child: SizedBox(
        width: _labelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Material(
              color: colors.surface,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: action.onPressed,
                child: SizedBox(
                  width: _circle,
                  height: _circle,
                  child: Center(
                    child: Icon(action.icon, size: 24, color: colors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              action.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
