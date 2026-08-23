import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';

/// A white surface lifted off the canvas — the reference design's card.
///
/// The theme keeps `Card` flat with no shadow, because PayPaw paints its own
/// soft shadows rather than using Material elevation. This widget is where that
/// happens, so no screen assembles a card out of `Container` and `BoxDecoration`
/// by hand.
///
/// Pass [onTap] to make the whole card tappable; the ripple is clipped to the
/// card's corners.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardInset),
    this.borderRadius = AppRadii.card,
    this.shadow = AppShadows.card,
    this.color = AppColors.surface,
    super.key,
  });

  /// Card contents.
  final Widget child;

  /// Makes the card tappable. Leave null for a card that only displays.
  final VoidCallback? onTap;

  /// Inner padding. Set `EdgeInsets.zero` for a card whose child paints to the
  /// edge, such as one holding an image or a list.
  final EdgeInsetsGeometry padding;

  /// Corner radius. [AppRadii.panel] for a larger summary panel.
  final BorderRadius borderRadius;

  /// Shadow. [AppShadows.floating] for something that sits above other cards.
  final List<BoxShadow> shadow;

  /// Surface colour. Rarely changed.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      // Shadow only, no colour: the Material below paints the surface, and a
      // coloured ancestor here would swallow the ink splash.
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadow),
      child: Material(
        color: color,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
