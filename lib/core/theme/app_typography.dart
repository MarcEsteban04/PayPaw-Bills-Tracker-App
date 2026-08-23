import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

/// PayPaw's type scale.
///
/// The reference design uses a geometric-humanist sans with tight tracking on
/// large text; Inter is the closest freely available match, so it is the app
/// typeface throughout.
///
/// **The styles here carry no colour.** Size, weight, tracking and line height
/// are the same in light and dark mode; only the colour changes, so it is applied
/// once in [textTheme] from the active [AppPalette]. A style with a baked-in
/// colour would be invisible in one of the two themes.
///
/// **Before release:** `google_fonts` fetches Inter over the network on first
/// launch and caches it, which means a brief fallback-font flash and no Inter at
/// all for a user who is offline on first run. Bundle the Inter `.ttf` files
/// under `assets/fonts/` — `google_fonts` prefers bundled files automatically —
/// as part of the release sprints.
abstract final class AppTypography {
  /// Hero figures — the dashboard's headline amount.
  static TextStyle get displaySmall => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.6,
  );

  /// Screen titles: "Dashboard", "Search".
  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
  );

  /// Sub-headline, and the value inside a summary card.
  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Emphasised figures inside a card — a bill amount, a percentage.
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );

  /// Card titles — a bill name, a section heading.
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.1,
  );

  /// Minor headings and tab labels.
  static TextStyle get titleSmall =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4);

  /// Lead body copy.
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Default body copy.
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Captions and timestamps — "2h ago".
  static TextStyle get bodySmall =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);

  /// Button labels. Semibold at 15 keeps white-on-orange within WCAG's
  /// large-text allowance; see `AppPalette.primary`.
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Chip and meta-pill labels.
  static TextStyle get labelMedium =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2);

  /// Bottom navigation labels and other very small labels.
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Monetary figures.
  ///
  /// [titleLarge] plus tabular figures, so digits occupy equal width and a
  /// column of amounts lines up instead of shifting per row. Use it anywhere a
  /// number sits above or below another number.
  static TextStyle amount(AppPalette palette) => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: palette.textPrimary,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The full Material text theme, coloured for [palette].
  ///
  /// Built on `GoogleFonts.interTextTheme()` rather than a bare `TextTheme`, so
  /// that every one of Material's fifteen slots is Inter. A partial TextTheme
  /// leaves the slots it omits at their Roboto defaults, which shows up as one
  /// stray Roboto label on an otherwise Inter screen.
  static TextTheme textTheme(AppPalette palette) {
    return GoogleFonts.interTextTheme()
        .apply(
          // Covers the slots not listed below, so nothing inherits a colour from
          // the wrong theme.
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
        )
        .copyWith(
          displaySmall: displaySmall.copyWith(color: palette.textPrimary),
          headlineMedium: headlineMedium.copyWith(color: palette.textPrimary),
          headlineSmall: headlineSmall.copyWith(color: palette.textPrimary),
          titleLarge: titleLarge.copyWith(color: palette.textPrimary),
          titleMedium: titleMedium.copyWith(color: palette.textPrimary),
          titleSmall: titleSmall.copyWith(color: palette.textPrimary),
          bodyLarge: bodyLarge.copyWith(color: palette.textPrimary),
          bodyMedium: bodyMedium.copyWith(color: palette.textSecondary),
          bodySmall: bodySmall.copyWith(color: palette.textTertiary),
          labelLarge: labelLarge.copyWith(color: palette.textPrimary),
          labelMedium: labelMedium.copyWith(color: palette.textTertiary),
          labelSmall: labelSmall.copyWith(color: palette.textTertiary),
        );
  }
}
