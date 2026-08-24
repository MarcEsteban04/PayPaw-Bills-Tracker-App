import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../domain/entities/category.dart';

/// Turns a category's stored `icon_name` into an actual icon.
///
/// ## Why this is an explicit map and not a lookup
///
/// Flutter tree-shakes the icon font: only the `IconData` constants it can see in
/// the source survive the build. Resolving a name to an icon at runtime — through
/// a generated table or `IconData(codePoint)` — means the glyph is not in the
/// font, and every category renders as an empty box in release while looking
/// perfect in debug. Thirteen lines of switch is the price of that not happening,
/// and `--no-tree-shake-icons` is a worse trade for the same thing.
///
/// A name with no entry falls back rather than throwing. A category added to the
/// database by hand should show a generic icon, not crash the picker.
abstract final class CategoryIcons {
  /// The identifiers seeded by `0004_categories.sql`, and nothing else. A test
  /// asserts every seeded name resolves to something other than the fallback.
  static IconData forName(String iconName) => switch (iconName) {
    'bolt' => Icons.bolt,
    'water_drop' => Icons.water_drop,
    'wifi' => Icons.wifi,
    'smartphone' => Icons.smartphone,
    'home' => Icons.home,
    'subscriptions' => Icons.subscriptions,
    'health_and_safety' => Icons.health_and_safety,
    'account_balance' => Icons.account_balance,
    'credit_card' => Icons.credit_card,
    'school' => Icons.school,
    'directions_bus' => Icons.directions_bus,
    'shopping_basket' => Icons.shopping_basket,
    'more_horiz' => Icons.more_horiz,
    _ => fallback,
  };

  /// Shown for an identifier this build does not know.
  static const IconData fallback = Icons.label_outline;

  /// Parses `#RRGGBB`, or null when the column was null or malformed.
  ///
  /// Null means "use the palette", which is what the column comment says.
  static Color? parseColor(String? hex) {
    if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
      return null;
    }

    final int? value = int.tryParse(hex.substring(1), radix: 16);

    return value == null ? null : Color(0xFF000000 | value);
  }
}

/// A category's icon on its own tinted surface.
///
/// A rounded square rather than a circle. Circles read as avatars — a person, an
/// account, something with an identity — and these are labels for a kind of thing.
/// The squircle also sits better beside the card corners it lives inside.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({required this.category, this.size = 40, super.key});

  final Category category;

  /// Diameter of the circle. The glyph is sized from it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    // The category's own colour when it has one, the app's accent when it does
    // not — which is what a null `color_hex` means.
    final Color tint =
        CategoryIcons.parseColor(category.colorHex) ?? colors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // A wash of the category's colour rather than the colour itself: a solid
        // fill at thirteen different hues turns a list into a paint chart.
        color: tint.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      ),
      child: Center(
        child: Icon(
          CategoryIcons.forName(category.iconName),
          size: size * 0.52,
          color: tint,
        ),
      ),
    );
  }
}
