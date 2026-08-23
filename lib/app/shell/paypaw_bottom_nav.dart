import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import 'app_destination.dart';

/// PayPaw's bottom navigation, built to match
/// `design/bottom_nav_ference/bottom_nav_ref.png`.
///
/// A dark pill floating above the content, not a bar attached to the bottom
/// edge. The selected destination is a lime pill carrying a black icon and
/// label; the rest are recessed circular icon buttons.
///
/// Because it floats *over* content, every scrollable screen must pad its
/// bottom by [AppSpacing.bottomNavClearance] or its last item ends up
/// underneath this.
class PayPawBottomNav extends StatelessWidget {
  const PayPawBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// Index into [AppDestination.values].
  final int currentIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  /// Height of the bar itself, excluding the floating margin.
  static const double _barHeight = 64;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // The bar supplies its own bottom gap, so the safe area only needs to keep
      // it clear of the system gesture inset.
      minimum: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.navSurface,
            borderRadius: AppRadii.round,
            boxShadow: AppShadows.floating,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final AppDestination destination in AppDestination.values)
                _NavItem(
                  destination: destination,
                  isSelected: destination.index == currentIndex,
                  onTap: () => onDestinationSelected(destination.index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination: a recessed circle, or the lime pill when selected.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  /// Both states are 48dp tall, so selecting a destination does not shift the
  /// row vertically — and 48dp is the minimum accessible tap target.
  static const double _itemSize = 48;

  static const Duration _duration = Duration(milliseconds: 260);
  static const Curve _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      // The pill renders the label as text as well. Without excluding the
      // subtree, a screen reader announces the destination twice.
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.round,
        // A dark surface needs a light ripple; the default dark one is invisible.
        splashColor: AppColors.textOnDark.withValues(alpha: 0.12),
        highlightColor: AppColors.textOnDark.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: _duration,
          curve: _curve,
          height: _itemSize,
          constraints: const BoxConstraints(minWidth: _itemSize),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? AppSpacing.lg : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.navActivePill
                : AppColors.navItemSunken,
            borderRadius: AppRadii.round,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: isSelected
                    ? AppColors.navOnActivePill
                    : AppColors.navInactiveIcon,
              ),
              // The label only exists in the selected state. AnimatedSize
              // widens the pill rather than snapping it, which is what makes the
              // selection read as one movement.
              AnimatedSize(
                duration: _duration,
                curve: _curve,
                child: isSelected
                    ? _NavItemLabel(text: destination.label)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The selected destination's label. Kept separate so the shrink/grow animation
/// has a single stable child to measure.
class _NavItemLabel extends StatelessWidget {
  const _NavItemLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.navOnActivePill, fontSize: 13),
      ),
    );
  }
}
