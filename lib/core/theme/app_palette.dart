import 'package:flutter/material.dart';

/// Every colour PayPaw is allowed to use, as a theme extension.
///
/// This replaced a flat class of `static const Color` values. Constants cannot
/// change with brightness, so with them a dark theme is impossible — which is
/// exactly what Sprint 10 ran into. Colours now come from the theme, so a widget
/// asks `context.colors.surface` and gets the right answer in either mode
/// without knowing which mode it is in.
///
/// Material's own `ColorScheme` covers only part of what this design needs: it
/// has no slot for a peach canvas gradient, a lime navigation pill, a third text
/// grey, or eight status tints. Rather than split colours across two lookups —
/// some from `colorScheme`, some from here — **everything** lives here, and
/// `AppTheme` builds the `ColorScheme` from it. One rule for widgets: use
/// `context.colors`.
///
/// Values are documented in `docs/design_system.md`. The light set is sampled
/// from the reference design; the dark set is derived from it, since the
/// reference is light-only.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.canvasPeach,
    required this.canvasCream,
    required this.canvasWhite,
    required this.primary,
    required this.primaryPressed,
    required this.primaryText,
    required this.primarySoft,
    required this.navSurface,
    required this.navActivePill,
    required this.navOnActivePill,
    required this.navItemSunken,
    required this.navInactiveIcon,
    required this.paid,
    required this.dueSoon,
    required this.overdue,
    required this.info,
    required this.paidTint,
    required this.paidText,
    required this.dueSoonTint,
    required this.dueSoonText,
    required this.overdueTint,
    required this.overdueText,
    required this.infoTint,
    required this.infoText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnPrimary,
    required this.textOnDark,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceInput,
    required this.border,
    required this.disabled,
    required this.onDisabled,
    required this.shadowSubtle,
    required this.shadowCard,
    required this.shadowFloating,
    required this.glow,
  });

  /// Which mode this palette is. Handy for the rare widget that genuinely needs
  /// to branch rather than just pick a colour.
  final Brightness brightness;

  // --- Canvas ---------------------------------------------------------------

  /// Warmest stop of the app background.
  final Color canvasPeach;

  /// Mid stop of the app background.
  final Color canvasCream;

  /// Coolest stop of the app background.
  final Color canvasWhite;

  // --- Brand ----------------------------------------------------------------

  /// Fills: buttons, active indicators, accents.
  final Color primary;

  /// Pressed state of [primary].
  final Color primaryPressed;

  /// Orange as *text or an icon on a light surface*, darkened (or lightened, in
  /// dark mode) to clear 4.5:1 where [primary] would not.
  final Color primaryText;

  /// Soft wash behind tinted icons.
  final Color primarySoft;

  // --- Bottom navigation ----------------------------------------------------

  /// Surface of the floating navigation bar.
  ///
  /// Darker than the canvas in light mode and *lighter* than it in dark mode —
  /// in both cases so the bar reads as floating above the page.
  final Color navSurface;

  /// The active destination's pill. Lime in both modes; it is the brand's
  /// navigation accent and it works on either background.
  final Color navActivePill;

  /// Icon and label on [navActivePill].
  final Color navOnActivePill;

  /// Recessed circle behind an inactive navigation icon.
  final Color navItemSunken;

  /// Inactive navigation icons.
  final Color navInactiveIcon;

  // --- Status fills ---------------------------------------------------------

  /// Paid, on track, positive progress.
  final Color paid;

  /// Approaching its date but not yet late.
  final Color dueSoon;

  /// Past its date.
  final Color overdue;

  /// Informational.
  final Color info;

  // --- Status tints ---------------------------------------------------------
  //
  // Each tint is paired with a text colour that clears 4.5:1 on it. Never mix
  // one status's tint with another's text.

  final Color paidTint;
  final Color paidText;
  final Color dueSoonTint;
  final Color dueSoonText;
  final Color overdueTint;
  final Color overdueText;
  final Color infoTint;
  final Color infoText;

  // --- Text -----------------------------------------------------------------

  /// Headings and amounts.
  final Color textPrimary;

  /// Supporting copy.
  final Color textSecondary;

  /// Meta text. The lightest any text in PayPaw gets, and still 4.5:1.
  final Color textTertiary;

  /// Text on [primary] and other saturated fills.
  final Color textOnPrimary;

  /// Text on [navSurface].
  final Color textOnDark;

  // --- Surfaces -------------------------------------------------------------

  /// Cards, sheets, dialogs.
  final Color surface;

  /// Chips and inactive fills.
  final Color surfaceMuted;

  /// Input field fill.
  final Color surfaceInput;

  /// Hairline dividers and card borders.
  final Color border;

  /// Disabled fills.
  final Color disabled;

  /// Text on [disabled]. Still 4.5:1 — a disabled control must stay readable.
  final Color onDisabled;

  // --- Shadow colours -------------------------------------------------------
  //
  // Only the colours vary by theme; the blur and offset of each shadow role are
  // fixed, so the shadow lists are derived below rather than stored.

  /// Colour of the lightest lift.
  final Color shadowSubtle;

  /// Colour of the default card shadow.
  final Color shadowCard;

  /// Colour of the shadow under floating elements.
  final Color shadowFloating;

  /// Warm glow under the primary CTA. Orange rather than black, which is what
  /// stops the button looking pasted onto the page.
  final Color glow;

  // --- Derived --------------------------------------------------------------

  /// The app background. Reproducing this diagonal fade is most of what makes a
  /// screen look like the reference design.
  LinearGradient get canvas => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[canvasPeach, canvasCream, canvasWhite],
    stops: const <double>[0, 0.45, 1],
  );

  /// Barely-there lift: chips, inline controls.
  List<BoxShadow> get subtleShadow => <BoxShadow>[
    BoxShadow(color: shadowSubtle, blurRadius: 8, offset: const Offset(0, 2)),
  ];

  /// The default card shadow.
  List<BoxShadow> get cardShadow => <BoxShadow>[
    BoxShadow(color: shadowCard, blurRadius: 20, offset: const Offset(0, 4)),
  ];

  /// Elements floating above content: the navigation, sheets, menus.
  List<BoxShadow> get floatingShadow => <BoxShadow>[
    BoxShadow(
      color: shadowFloating,
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// The glow beneath the primary CTA.
  List<BoxShadow> get primaryGlow => <BoxShadow>[
    BoxShadow(color: glow, blurRadius: 20, offset: const Offset(0, 8)),
  ];

  /// Background for a status chip of [tone].
  Color statusTint(AppStatusTone tone) => switch (tone) {
    AppStatusTone.paid => paidTint,
    AppStatusTone.dueSoon => dueSoonTint,
    AppStatusTone.overdue => overdueTint,
    AppStatusTone.info => infoTint,
    AppStatusTone.neutral => surfaceMuted,
  };

  /// Label colour for a status chip of [tone]. Always paired with
  /// [statusTint] of the same tone.
  Color statusText(AppStatusTone tone) => switch (tone) {
    AppStatusTone.paid => paidText,
    AppStatusTone.dueSoon => dueSoonText,
    AppStatusTone.overdue => overdueText,
    AppStatusTone.info => infoText,
    AppStatusTone.neutral => textSecondary,
  };

  // --- The two palettes -----------------------------------------------------

  /// Sampled from `design/app_ref_design/`.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    canvasPeach: Color(0xFFFDEEE3),
    canvasCream: Color(0xFFFFF7F1),
    canvasWhite: Color(0xFFFFFDFC),
    primary: Color(0xFFF26B21),
    primaryPressed: Color(0xFFD95A14),
    primaryText: Color(0xFFC2410C),
    primarySoft: Color(0xFFFFF1E8),
    navSurface: Color(0xFF17181A),
    navActivePill: Color(0xFFD9F94A),
    navOnActivePill: Color(0xFF0F1011),
    navItemSunken: Color(0xFF0E0F10),
    navInactiveIcon: Color(0xFFB6BBC1),
    paid: Color(0xFF34C759),
    dueSoon: Color(0xFFF5A623),
    overdue: Color(0xFFE5484D),
    info: Color(0xFF3B82F6),
    paidTint: Color(0xFFE7F8EC),
    paidText: Color(0xFF1B7A32),
    dueSoonTint: Color(0xFFFFF4E0),
    dueSoonText: Color(0xFF8A5200),
    overdueTint: Color(0xFFFDECEC),
    overdueText: Color(0xFFB3262A),
    infoTint: Color(0xFFE8F0FE),
    infoText: Color(0xFF1A4FA0),
    textPrimary: Color(0xFF1A1A1C),
    textSecondary: Color(0xFF5F5F66),
    textTertiary: Color(0xFF6A6A74),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnDark: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F2F0),
    surfaceInput: Color(0xFFF7F5F3),
    border: Color(0xFFECE8E4),
    disabled: Color(0xFFE3E0DC),
    onDisabled: Color(0xFF5E5A56),
    shadowSubtle: Color(0x0A000000),
    shadowCard: Color(0x0D000000),
    shadowFloating: Color(0x1F000000),
    glow: Color(0x40F26B21),
  );

  /// Derived from [light], since the reference design has no dark mode.
  ///
  /// Three decisions shape it:
  ///
  /// * The canvas is a **warm** charcoal, not neutral black, so the peach
  ///   character survives the inversion.
  /// * The navigation bar becomes *lighter* than the canvas rather than darker.
  ///   In light mode a dark bar floats; in dark mode a darker bar would sink.
  /// * Shadows are much stronger. A 5%-black shadow is invisible on charcoal,
  ///   so the alpha rises to keep cards reading as lifted.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    canvasPeach: Color(0xFF1A1512),
    canvasCream: Color(0xFF151312),
    canvasWhite: Color(0xFF111111),
    primary: Color(0xFFF26B21),
    primaryPressed: Color(0xFFD95A14),
    primaryText: Color(0xFFFFA06B),
    primarySoft: Color(0xFF3A2416),
    navSurface: Color(0xFF262324),
    navActivePill: Color(0xFFD9F94A),
    navOnActivePill: Color(0xFF0F1011),
    navItemSunken: Color(0xFF1A1819),
    navInactiveIcon: Color(0xFFB6BBC1),
    paid: Color(0xFF34C759),
    dueSoon: Color(0xFFF5A623),
    overdue: Color(0xFFFF5A5F),
    info: Color(0xFF5B9BFF),
    paidTint: Color(0xFF14301E),
    paidText: Color(0xFF7BE8A0),
    dueSoonTint: Color(0xFF33260A),
    dueSoonText: Color(0xFFF6C765),
    overdueTint: Color(0xFF3A1618),
    overdueText: Color(0xFFFF9A9D),
    infoTint: Color(0xFF132A45),
    infoText: Color(0xFF8FBBFF),
    textPrimary: Color(0xFFF5F3F1),
    textSecondary: Color(0xFFB5B0AC),
    textTertiary: Color(0xFFA39D96),
    textOnPrimary: Color(0xFFFFFFFF),
    textOnDark: Color(0xFFF5F5F7),
    surface: Color(0xFF1F1D1C),
    surfaceMuted: Color(0xFF2A2726),
    surfaceInput: Color(0xFF232120),
    border: Color(0xFF322E2C),
    disabled: Color(0xFF2E2A28),
    onDisabled: Color(0xFFA6A199),
    shadowSubtle: Color(0x33000000),
    shadowCard: Color(0x4D000000),
    shadowFloating: Color(0x66000000),
    glow: Color(0x40F26B21),
  );

  /// Returns `this`.
  ///
  /// `ThemeExtension` requires the method, but PayPaw has exactly two palettes
  /// and nothing partially overrides one — you pick light or dark. A 39-argument
  /// `copyWith` nobody calls would be noise, so this is deliberately a no-op.
  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) {
      return this;
    }

    // Interpolated rather than snapped at the midpoint, because `MaterialApp`
    // animates a theme change and a snap would show as a flash halfway through.
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;

    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      canvasPeach: mix(canvasPeach, other.canvasPeach),
      canvasCream: mix(canvasCream, other.canvasCream),
      canvasWhite: mix(canvasWhite, other.canvasWhite),
      primary: mix(primary, other.primary),
      primaryPressed: mix(primaryPressed, other.primaryPressed),
      primaryText: mix(primaryText, other.primaryText),
      primarySoft: mix(primarySoft, other.primarySoft),
      navSurface: mix(navSurface, other.navSurface),
      navActivePill: mix(navActivePill, other.navActivePill),
      navOnActivePill: mix(navOnActivePill, other.navOnActivePill),
      navItemSunken: mix(navItemSunken, other.navItemSunken),
      navInactiveIcon: mix(navInactiveIcon, other.navInactiveIcon),
      paid: mix(paid, other.paid),
      dueSoon: mix(dueSoon, other.dueSoon),
      overdue: mix(overdue, other.overdue),
      info: mix(info, other.info),
      paidTint: mix(paidTint, other.paidTint),
      paidText: mix(paidText, other.paidText),
      dueSoonTint: mix(dueSoonTint, other.dueSoonTint),
      dueSoonText: mix(dueSoonText, other.dueSoonText),
      overdueTint: mix(overdueTint, other.overdueTint),
      overdueText: mix(overdueText, other.overdueText),
      infoTint: mix(infoTint, other.infoTint),
      infoText: mix(infoText, other.infoText),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      textOnPrimary: mix(textOnPrimary, other.textOnPrimary),
      textOnDark: mix(textOnDark, other.textOnDark),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceInput: mix(surfaceInput, other.surfaceInput),
      border: mix(border, other.border),
      disabled: mix(disabled, other.disabled),
      onDisabled: mix(onDisabled, other.onDisabled),
      shadowSubtle: mix(shadowSubtle, other.shadowSubtle),
      shadowCard: mix(shadowCard, other.shadowCard),
      shadowFloating: mix(shadowFloating, other.shadowFloating),
      glow: mix(glow, other.glow),
    );
  }
}

/// What a status chip is saying.
///
/// Presentation-level on purpose. It is not a bill status: the domain has not
/// been modelled yet, and when it is, a bill's status will map *onto* a tone
/// rather than being one. Subscriptions and debts map onto the same tones.
///
/// It lives here rather than with the chip widget because the palette resolves
/// each tone to its tint and text colour, and those differ by theme.
enum AppStatusTone {
  /// Settled, on track, done.
  paid,

  /// Approaching its date but not yet late.
  dueSoon,

  /// Past its date.
  overdue,

  /// Worth noticing, but neither good nor bad — 'Auto-pay', 'Shared'.
  info,

  /// No judgement — 'Draft', 'Archived'.
  neutral,
}

/// The one way a widget reads a colour.
extension AppPaletteContext on BuildContext {
  /// PayPaw's colours for the active theme.
  ///
  /// Throws if the extension is missing, which would mean a `ThemeData` was
  /// built without `AppTheme` — worth failing loudly rather than silently
  /// falling back to Material defaults that look nothing like the design.
  AppPalette get colors => Theme.of(this).extension<AppPalette>()!;
}
