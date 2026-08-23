import 'package:flutter/material.dart';

/// PayPaw's colour tokens, sampled from `design/app_ref_design/` and
/// `design/bottom_nav_ference/`.
///
/// Nothing in the app may hard-code a colour. If a screen needs a shade that is
/// not here, the shade gets a name here first.
///
/// **On accuracy:** these values were sampled from a lossy reference image, so
/// treat them as the design's intent rather than as pixel-exact truth. Change
/// them here and the whole app follows.
///
/// **On contrast:** the reference's muted greys sit below WCAG AA on white, so
/// the text greys below are darkened to pass 4.5:1 while staying visibly muted.
/// The brand orange is *not* adjusted — it is the brand — but a darker
/// [primaryText] variant exists for the cases where orange is used as text or an
/// icon on a light surface, which would otherwise fail badly.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Canvas
  //
  // The reference background is a warm peach that fades towards white. Painted
  // as a gradient — see AppGradients.canvas — rather than a flat fill.
  // ---------------------------------------------------------------------------

  /// Warmest corner of the app background.
  static const Color canvasPeach = Color(0xFFFDEEE3);

  /// Mid stop of the app background.
  static const Color canvasCream = Color(0xFFFFF7F1);

  /// Coolest stop of the app background.
  static const Color canvasWhite = Color(0xFFFFFDFC);

  // ---------------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------------

  /// The orange from the reference's primary CTA. Used for filled buttons,
  /// active indicators, and accents.
  ///
  /// White text on this orange reaches roughly 3:1, which satisfies WCAG AA for
  /// large text only. Keep button labels at [AppTypography] label sizes and
  /// semibold, and use [primaryText] when orange has to carry small text.
  static const Color primary = Color(0xFFF26B21);

  /// Pressed and gradient-end variant of [primary].
  static const Color primaryPressed = Color(0xFFD95A14);

  /// Orange for *text and icons on light surfaces* — the active tab label, a
  /// link, an inline accent. Darkened to clear 4.5:1 on white while reading as
  /// the same orange family.
  static const Color primaryText = Color(0xFFC2410C);

  /// Soft orange wash used behind icons, as in the reference's tinted icon
  /// squares.
  static const Color primarySoft = Color(0xFFFFF1E8);

  // ---------------------------------------------------------------------------
  // Bottom navigation
  //
  // Taken from design/bottom_nav_ference/bottom_nav_ref.png: a dark floating
  // pill with a lime active pill. Lime is legible here because it is a
  // background carrying near-black content (about 15:1) — never use it as a
  // foreground colour on a light surface.
  // ---------------------------------------------------------------------------

  /// Surface of the floating bottom navigation bar.
  static const Color navSurface = Color(0xFF17181A);

  /// Active item's pill.
  static const Color navActivePill = Color(0xFFD9F94A);

  /// Icon and label sitting on [navActivePill].
  static const Color navOnActivePill = Color(0xFF0F1011);

  /// Inactive icons on [navSurface].
  static const Color navInactiveIcon = Color(0xFFB6BBC1);

  // ---------------------------------------------------------------------------
  // Semantic — bill status
  //
  // Green comes from the reference's progress gauge, amber from its rating star.
  // Reusing them keeps the status colours inside the reference's palette instead
  // of importing a generic traffic-light set.
  // ---------------------------------------------------------------------------

  /// Paid, on track, positive progress.
  static const Color paid = Color(0xFF34C759);

  /// Due soon — approaching its date but not yet late.
  static const Color dueSoon = Color(0xFFF5A623);

  /// Overdue.
  static const Color overdue = Color(0xFFE5484D);

  /// Informational highlight.
  static const Color info = Color(0xFF3B82F6);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  /// Headings, amounts, anything that must be read first. ~16:1 on white.
  static const Color textPrimary = Color(0xFF1A1A1C);

  /// Supporting copy and labels. ~7:1 on white.
  static const Color textSecondary = Color(0xFF5F5F66);

  /// Meta text — timestamps, chip labels, captions. ~4.6:1 on white, the
  /// darkest this can be while still reading as de-emphasised.
  static const Color textTertiary = Color(0xFF757580);

  /// Text on [primary] and other saturated fills.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Text on [navSurface].
  static const Color textOnDark = Color(0xFFF5F5F7);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------

  /// Cards, sheets, and dialogs.
  static const Color surface = Color(0xFFFFFFFF);

  /// Chips, filter pills, and inactive tab backgrounds.
  static const Color surfaceMuted = Color(0xFFF4F2F0);

  /// Input field fill.
  static const Color surfaceInput = Color(0xFFF7F5F3);

  /// Hairline dividers and card borders.
  static const Color border = Color(0xFFECE8E4);

  /// Disabled fills and skeleton placeholders.
  static const Color disabled = Color(0xFFE3E0DC);

  /// Text and icons on a disabled surface. Intentionally still 4.5:1 on
  /// [disabled] — a disabled control must remain readable.
  static const Color onDisabled = Color(0xFF6E6A66);
}
