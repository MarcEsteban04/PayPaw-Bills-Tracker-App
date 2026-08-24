import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// A surface lifted off the canvas — the reference design's card.
///
/// The theme keeps `Card` flat with no shadow, because PayPaw paints its own
/// soft shadows rather than using Material elevation. This widget is where that
/// happens, so no screen assembles a card out of `Container` and `BoxDecoration`
/// by hand.
///
/// Pass [onTap] to make the whole card tappable; the ripple is clipped to the
/// card's corners.
///
/// [shadow] and [color] default to null rather than to a value, because their
/// defaults come from the theme and a default argument cannot read one. Null
/// means "whatever this theme says a card looks like", which is what almost
/// every caller wants.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.cardInset),
    this.borderRadius = AppRadii.card,
    this.shadow,
    this.color,
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

  /// Shadow. Null uses the theme's card shadow; pass
  /// `context.colors.floatingShadow` for something sitting above other cards.
  final List<BoxShadow>? shadow;

  /// Surface colour. Null uses the theme's card surface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.colors;
    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      // Shadow only, no colour: the Material below paints the surface, and a
      // coloured ancestor here would swallow the ink splash.
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ?? palette.cardShadow,
      ),
      // The hairline goes on the Material, not the DecoratedBox above it: drawn
      // outside, the ink splash would run over the top of it on every tap.
      //
      // Null in light mode, where the shadow already gives the card an edge. See
      // [AppPalette.cardBorder].
      //
      // `shape` and `borderRadius` are mutually exclusive on `Material` — it
      // asserts if given both — so the rounding is expressed one way or the
      // other, never both.
      child: Material(
        color: color ?? palette.surface,
        borderRadius: palette.cardBorder == null ? borderRadius : null,
        shape: palette.cardBorder == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: borderRadius,
                side: BorderSide(color: palette.border),
              ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
