import 'package:flutter/material.dart';

import '../../../../core/domain/stable_hash.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';

/// A colour and a monogram for a service, derived from its name.
///
/// ## Why not the real logos
///
/// Because they would have to come from somewhere. A logo service is a network
/// request per row, a third party learning which subscriptions this user has,
/// and a screen that is blank until it answers. Bundling them means shipping
/// other companies' trademarks in the APK and a list that only recognises the
/// forty brands somebody thought of.
///
/// A generated mark recognises **every** service, works offline, and costs
/// nothing. It is not the brand, but it does the job a brand does on a list:
/// tell you which row is which before you have read it.
///
/// ## The colour must not move
///
/// It comes from [stableHash] of the lowercased name, so Netflix is the same
/// colour on every device, in every build, forever. A palette that shuffled
/// between releases would be worse than no colour at all — people learn a list
/// by its shape, and re-teaching it every update is a tax with no benefit.
abstract final class SubscriptionMarks {
  /// The hues a provider can be given.
  ///
  /// A curated set rather than a hue rotation over the hash. Free-running HSL
  /// produces muddy yellows and greens that vanish on the light theme and glare
  /// on the dark one; these are picked to sit at similar weight against both,
  /// and to stay distinguishable from the app's own accent.
  static const List<Color> palette = <Color>[
    Color(0xFFEF4444), // red
    Color(0xFFF97316), // orange
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFF6366F1), // indigo
    Color(0xFFA855F7), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
  ];

  /// The colour for [provider]. Case and surrounding space do not change it.
  static Color colorFor(String provider) =>
      palette[stableHash(provider.trim().toLowerCase()) % palette.length];

  /// One or two letters standing in for [provider].
  ///
  /// The first letter of each of the first two words — "Apple TV+" gives "AT",
  /// "Netflix" gives "N". Non-letters are dropped first, so "Disney+" is "D"
  /// rather than "D+", and a name that is nothing but punctuation falls back to
  /// a bullet rather than rendering an empty square.
  static String initialsFor(String provider) {
    final Iterable<String> words = provider
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((String word) => word.isNotEmpty)
        .take(2);

    if (words.isEmpty) {
      return '•';
    }

    return words.map((String word) => word[0].toUpperCase()).join();
  }
}

/// A service's monogram on its own tinted surface.
///
/// Deliberately the same shape and weight as `CategoryIcon`: a rounded square at
/// a wash of its own colour, with the mark at full strength. The two appear on
/// sibling screens and a subscription row that invented its own geometry would
/// make the app look assembled rather than designed.
class SubscriptionMark extends StatelessWidget {
  const SubscriptionMark({
    required this.provider,
    this.size = 44,
    this.isMuted = false,
    super.key,
  });

  final String provider;

  final double size;

  /// Drains the colour, for a subscription that has been stopped.
  ///
  /// A cancelled service should not be the brightest thing in the row. It stays
  /// on the list — it is the record of a decision — but it stops looking like
  /// money going out.
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    final Color tint = isMuted
        ? colors.textTertiary
        : SubscriptionMarks.colorFor(provider);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // A wash rather than the colour itself: a column of solid fills at ten
        // different hues turns a list into a paint chart.
        color: tint.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      ),
      child: Center(
        child: Text(
          SubscriptionMarks.initialsFor(provider),
          style: TextStyle(
            color: tint,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            // Tightened, because two capitals at this weight otherwise read as
            // two separate marks rather than one.
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
