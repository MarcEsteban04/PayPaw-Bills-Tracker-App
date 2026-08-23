import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// PayPaw's type scale.
///
/// The reference design uses a geometric-humanist sans with tight tracking on
/// large text; Inter is the closest freely available match, so it is the app
/// typeface throughout.
///
/// **Before release:** `google_fonts` fetches Inter over the network on first
/// launch and caches it, which means a brief fallback-font flash and no Inter at
/// all for a user who is offline on first run. Bundle the Inter `.ttf` files
/// under `assets/fonts/` — `google_fonts` prefers bundled files automatically —
/// as part of the release sprints.
///
/// Sizes are mapped onto Material's [TextTheme] slots so that stock widgets
/// pick the right style without being told. Where the reference's role is not
/// obvious from the slot name, the doc comment says what it is for.
abstract final class AppTypography {
  /// Hero figures — the dashboard's headline amount.
  static TextStyle get displaySmall => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  /// Screen titles: "Dashboard", "Search".
  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.textPrimary,
  );

  /// Sub-headline, and the value inside a summary card.
  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  /// Emphasised figures inside a card — a bill amount, a percentage.
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Card titles — a bill name, a section heading.
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  /// Minor headings and tab labels.
  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Lead body copy.
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  /// Default body copy.
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// Captions and timestamps — "2h ago".
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  /// Button labels. Semibold at 15 keeps white-on-orange within WCAG's
  /// large-text allowance; see [AppColors.primary].
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  /// Chip and meta-pill labels.
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  /// Bottom navigation labels and other very small labels.
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
    color: AppColors.textTertiary,
  );

  /// Monetary figures.
  ///
  /// Same as [titleLarge] but with tabular figures, so digits occupy equal
  /// width and a column of amounts lines up instead of shifting per row. Use it
  /// anywhere a number sits above or below another number.
  static TextStyle get amount => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The full Material text theme.
  ///
  /// Built on `GoogleFonts.interTextTheme()` rather than a bare `TextTheme`, so
  /// that every one of Material's fifteen slots is Inter. A partial TextTheme
  /// leaves the slots it omits at their Roboto defaults, which shows up as one
  /// stray Roboto label on an otherwise Inter screen.
  static TextTheme get textTheme => GoogleFonts.interTextTheme().copyWith(
    displaySmall: displaySmall,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
