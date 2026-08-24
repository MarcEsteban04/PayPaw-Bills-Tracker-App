import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/presentation/layout/app_breakpoints.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radii.dart';
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
///
/// ## When there is not enough room
///
/// Four destinations, one of them a labelled pill, make this the widest thing in
/// the app relative to its container. On a 320dp screen, or at a large system
/// font size, the labelled pill stops fitting.
///
/// The response is to **drop the label and show icons only**, rather than let the
/// label truncate to `Calend…`. A clipped word reads as a bug; an icon-only bar
/// reads as a design. The threshold scales with the user's font size, so the
/// switch happens when the text actually stops fitting rather than at a width
/// guessed for one font size.
class PayPawBottomNav extends StatelessWidget {
  const PayPawBottomNav({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onAddPressed,
    super.key,
  });

  /// Index into [AppDestination.values].
  final int currentIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  /// Records a new bill.
  ///
  /// Lives beside the destinations rather than inside the pill, because it is not
  /// a destination — tapping it does not change which tab you are on, and putting
  /// an action in a row of places is how a navigation bar starts lying about what
  /// its items do.
  ///
  /// It is here rather than on a screen so it works from all four tabs. Adding a
  /// bill is the app's primary action, and having it only on the Bills tab meant
  /// finding the right tab first.
  final VoidCallback onAddPressed;

  /// Height of the bar itself, excluding the floating margin.
  static const double _barHeight = 64;

  /// Space between one destination and the next.
  ///
  /// Small on purpose: the destinations should read as a group, not as four
  /// separate buttons spread across the screen.
  static const double _itemGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    // scale(1) yields the user's effective text scale factor, already clamped by
    // PayPawApp.
    final double textScale = MediaQuery.textScalerOf(context).scale(1);

    return SafeArea(
      // The bar supplies its own bottom gap, so the safe area only needs to keep
      // it clear of the system gesture inset.
      minimum: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        // Centred and hugging its content, rather than stretched edge to edge.
        // Spreading four destinations across the full width left large gaps
        // between them; the reference bar is a compact pill.
        //
        // Align with heightFactor: 1, not Center. Center expands to fill the
        // height it is offered, and this slot is measured with the whole screen
        // as its maximum — the same trap that once put the bar at the top of the
        // display. There is a test for it.
        child: Align(
          heightFactor: 1,
          // The pill and the add button, side by side and centred as a pair. Two
          // surfaces rather than one: the dark pill is where you are, the green
          // circle is what you can do, and they should not look like the same
          // kind of thing.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(child: _navPill(context, textScale)),
              const SizedBox(width: AppSpacing.sm),
              _AddButton(onPressed: onAddPressed),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navPill(BuildContext context, double textScale) {
    return Container(
      height: _barHeight,
      // xs, not sm. The add button beside the bar took a fixed cut of the row,
      // and these eight points are the difference between the selected label
      // fitting on a 412dp phone and being dropped on every phone.
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: context.colors.navSurface,
        borderRadius: AppRadii.round,
        boxShadow: context.colors.floatingShadow,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The threshold scales *up* with text and never down. Larger text needs
          // a wider label, so the bar gives it up sooner — but smaller text does
          // not shrink the icons or their padding, which are fixed. Scaling the
          // threshold down let labels appear on a bar that could not hold them,
          // and it overflowed by a pixel at the app's minimum text scale.
          final bool showLabels =
              constraints.maxWidth >=
              AppBreakpoints.navLabelMinWidth * math.max(1, textScale);

          return Row(
            // min, so the bar is as wide as its destinations and no wider.
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AppDestination destination in AppDestination.values)
                // Flexible so no destination can push the row past the
                // available width. The selected pill needs more room than
                // the others, so it gets twice the share.
                Flexible(
                  // The selected item only needs the extra share when it is
                  // carrying a label. Giving it double the width in icon-only
                  // mode starves the other three, whose circles cannot shrink
                  // below the 48dp tap target — which showed up as the bar
                  // overflowing by five pixels once the add button took its cut
                  // of the row.
                  flex: showLabels && destination.index == currentIndex ? 2 : 1,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      // Tighter without labels, where every point counts.
                      horizontal: (showLabels ? _itemGap : AppSpacing.xs) / 2,
                    ),
                    child: _NavItem(
                      destination: destination,
                      isSelected: destination.index == currentIndex,
                      showLabel: showLabels,
                      onTap: () => onDestinationSelected(destination.index),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Records a bill, from any tab.
///
/// A circle rather than the extended pill the Bills screen used to carry: beside
/// a bar that is already a pill, a second pill reads as a fifth destination. The
/// icon alone is unambiguous here because the button is the only action on the
/// screen's furniture, and it keeps its tooltip and semantics label for anyone
/// who needs the word.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  /// Smaller than the bar, so the bar stays the anchor of the pair — and so it
  /// takes as little width as possible from it. Every point this button occupies
  /// is a point the four destinations do not have.
  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      button: true,
      label: 'Add bill',
      child: Tooltip(
        message: 'Add bill',
        // The shadow is painted by the container, not by Material's elevation:
        // the bar beside it uses the palette's own `floatingShadow`, and the two
        // have to match or one appears to hover above the other.
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: colors.floatingShadow,
          ),
          child: Material(
            color: colors.primary,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: _size,
                height: _size,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    size: 28,
                    color: colors.textOnPrimary,
                  ),
                ),
              ),
            ),
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
    required this.showLabel,
    required this.onTap,
  });

  final AppDestination destination;
  final bool isSelected;

  /// Whether there is room for the selected destination's label.
  final bool showLabel;

  final VoidCallback onTap;

  /// Both states are 48dp tall, so selecting a destination does not shift the
  /// row vertically — and 48dp is the minimum accessible tap target.
  static const double _itemSize = 48;

  static const Duration _duration = Duration(milliseconds: 260);
  static const Curve _curve = Curves.easeOutCubic;

  bool get _isLabelled => isSelected && showLabel;

  /// The label, or nothing when this destination is not the labelled one.
  Widget get _label => _isLabelled
      ? _NavItemLabel(text: destination.label)
      : const SizedBox.shrink();

  /// [_label], animated so the pill grows and shrinks rather than snapping.
  Widget _animatedLabel(Duration duration) =>
      AnimatedSize(duration: duration, curve: _curve, child: _label);

  @override
  Widget build(BuildContext context) {
    // Honour Android's "Remove animations" setting: the pill snaps to its new
    // shape instead of growing into it. Motion sensitivity is a real condition,
    // and an app that animates anyway is one the setting does not work on.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration duration = reduceMotion ? Duration.zero : _duration;

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
        splashColor: context.colors.textOnDark.withValues(alpha: 0.12),
        highlightColor: context.colors.textOnDark.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: duration,
          curve: _curve,
          height: _itemSize,
          constraints: const BoxConstraints(minWidth: _itemSize),
          padding: EdgeInsets.symmetric(
            // md rather than lg around a label: the pill hugs the word a little
            // more tightly, which is what keeps it inside its share of a bar
            // that now shares the row with the add button.
            horizontal: _isLabelled ? AppSpacing.md : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.navActivePill
                : context.colors.navItemSunken,
            borderRadius: AppRadii.round,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isSelected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: isSelected
                    ? context.colors.navOnActivePill
                    : context.colors.navInactiveIcon,
              ),
              // The label only exists on the selected destination, and only when
              // it fits. AnimatedSize widens the pill rather than snapping it,
              // which is what makes the selection read as one movement.
              //
              // Flexible matters more than it looks: an item's flex share
              // changes the instant selection moves, while its label takes 260ms
              // to animate away. For those 260ms the outgoing item is still
              // drawing a label in a slot already narrowed to icon width. Being
              // shrinkable lets it clip through the transition instead of
              // overflowing.
              //
              // With motion reduced, AnimatedSize is dropped rather than given
              // a zero duration — a zero-duration RenderAnimatedSize re-dirties
              // itself during layout and asserts.
              Flexible(child: reduceMotion ? _label : _animatedLabel(duration)),
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
        // Belt and braces: the width threshold should mean the label always
        // fits, but clipping here guarantees that an unexpected combination of
        // width and font size degrades quietly instead of throwing an overflow.
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: context.colors.navOnActivePill, fontSize: 13),
      ),
    );
  }
}
