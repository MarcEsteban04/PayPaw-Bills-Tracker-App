import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
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
/// **Only actions that work are here.** Sprint 37's list also names "Add debt"
/// and "Add subscription"; debts are Phase 11 and subscriptions are Phase 10, so
/// neither has anywhere to go. A row of five where two do nothing teaches the
/// user that the row is decoration, and they stop reading it. Each one arrives
/// when the thing behind it does — which is how "Mark paid" got here, once
/// recording a payment was real.
///
/// The rule runs per-user as well as per-sprint: "Mark paid" is absent for
/// somebody with nothing outstanding, because an action that opens onto an empty
/// list is the same broken promise as one that is not built.
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

    // The tap target is the circle *and* its label, not the circle alone.
    //
    // A label sitting under a button reads as part of it, and that is where a
    // thumb goes — under a 56dp circle there is a whole word that looked like a
    // control and was not one. Widening the ink to the column costs nothing and
    // removes a miss that would have felt like the app ignoring a tap.
    return Semantics(
      button: true,
      label: action.label,
      child: SizedBox(
        width: _labelWidth,
        child: InkWell(
          onTap: action.onPressed,
          borderRadius: AppRadii.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: _circle,
                height: _circle,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(action.icon, size: 24, color: colors.primary),
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
      ),
    );
  }
}
