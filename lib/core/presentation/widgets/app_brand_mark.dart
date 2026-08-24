import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../app_assets.dart';

/// The app's logo, and optionally its name beside it.
///
/// Shared rather than rebuilt per screen: the welcome screen and all three auth
/// screens show it, and the point of a brand mark is that it is identical
/// everywhere. It replaced a green rounded square with a Material paw glyph in
/// it — a stand-in that looked deliberate enough that it could have stayed.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({this.size = 40, this.showName = true, super.key});

  /// Height and width of the logo. The asset is square.
  final double size;

  /// Whether to print "PayPaw" beside it.
  ///
  /// Off where the logo is already the largest thing on screen and repeating the
  /// name next to it would be saying it twice.
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    final Widget logo = Image.asset(
      AppAssets.logo,
      width: size,
      height: size,
      // A 1254² PNG decoded at full size is ~6 MB of RAM for a 40dp mark.
      // Capped to what is actually drawn, at the device's pixel density.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      // The name sits beside it, and where it does not, a headline says the same
      // thing. Announcing the image would repeat whichever one is present.
      excludeFromSemantics: true,
    );

    if (!showName) {
      return logo;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        logo,
        const SizedBox(width: AppSpacing.sm),
        Text(
          'PayPaw',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
