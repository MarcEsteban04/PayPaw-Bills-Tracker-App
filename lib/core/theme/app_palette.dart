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
/// has no slot for the canvas gradient, a lime navigation pill, a third text
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
    required this.canvasStart,
    required this.canvasMid,
    required this.canvasEnd,
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

  /// Lightest stop of the app background.
  final Color canvasStart;

  /// Middle stop of the app background.
  final Color canvasMid;

  /// Deepest stop of the app background.
  final Color canvasEnd;

  // --- Brand ----------------------------------------------------------------

  /// Fills: buttons, active indicators, accents.
  final Color primary;

  /// Pressed state of [primary].
  final Color primaryPressed;

  /// The brand lime as *text or an icon on a surface*, darkened (or, in dark
  /// mode, kept as-is) to clear 4.5:1 where [primary] would not.
  ///
  /// The gap between this and [primary] is much wider than it was under the
  /// green brand: lime on white is about 1.4:1, so the light-mode value is a
  /// dark olive rather than a slightly deeper version of the fill.
  final Color primaryText;

  /// Soft lime wash. Behind tinted icons, and behind the reference design's
  /// promotional and referral cards.
  final Color primarySoft;

  // --- Bottom navigation ----------------------------------------------------

  /// Surface of the floating navigation bar.
  ///
  /// Near-black in both themes. It used to lift in dark mode so it would clear
  /// the charcoal canvas; against true black that made it a grey slab, and the
  /// bar takes its shape from its own contents instead.
  final Color navSurface;

  /// The active destination's pill. Lime in both modes; it is the brand's
  /// navigation accent and it works on either background.
  final Color navActivePill;

  /// Icon and label on [navActivePill].
  final Color navOnActivePill;

  /// Recessed circle behind an inactive navigation icon.
  ///
  /// The navigation bar no longer draws these — the unselected destinations are
  /// bare icons. Still used by the bills summary card, whose inner chips sit on
  /// a dark panel and need the same recess.
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

  /// Glow under the primary CTA. Tinted with the brand lime rather than black,
  /// which is what stops the button looking pasted onto the page.
  final Color glow;

  // --- Derived --------------------------------------------------------------

  /// The app background.
  ///
  /// Very nearly flat in light mode: the reference sits white content sheets on a
  /// plain light grey, so the three stops differ only slightly. The gradient is
  /// kept rather than replaced with a single colour because dark mode uses the
  /// same mechanism, and because a flat token would have to become a gradient
  /// again the first time a screen wants one.
  LinearGradient get canvas => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[canvasStart, canvasMid, canvasEnd],
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

  /// The hairline that gives a raised surface its edge — in dark mode only.
  ///
  /// Cards, panels, and the floating navigation bar.
  ///
  /// Light mode has no use for one: a white card on grey already has an edge and
  /// [cardShadow] lifts it off the page, and the bar is near-black on a light
  /// canvas. **On a true black canvas neither works.** A shadow is a shade of
  /// black and does nothing against black, and the fill difference alone leaves
  /// a surface that fades out rather than ending.
  ///
  /// So the two themes give a surface its edge by opposite means, and this is
  /// the half only one of them needs. Null rather than a transparent border, so
  /// the light-mode decoration is byte-for-byte what it was.
  BoxBorder? get surfaceBorder =>
      brightness == Brightness.dark ? Border.all(color: border) : null;

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
    canvasStart: Color(0xFFF3F4F6),
    canvasMid: Color(0xFFF0F1F3),
    canvasEnd: Color(0xFFECEEF1),
    primary: Color(0xFFD9F94A),
    primaryPressed: Color(0xFFC2E035),
    // **Not the lime.** As a fill on white, lime is fine with black on top of
    // it; as text or an icon *on* white it is around 1.4:1 and unreadable. This
    // is the same hue taken down to a dark olive that clears 4.5:1, which is
    // exactly the job `primaryText` has always had — the green version of this
    // was darker than `primary` for the same reason.
    primaryText: Color(0xFF4A5A00),
    primarySoft: Color(0xFFF6FCDC),
    navSurface: Color(0xFF0A0B0D),
    navActivePill: Color(0xFFD9F94A),
    navOnActivePill: Color(0xFF0F1011),
    navItemSunken: Color(0xFF1C1F24),
    navInactiveIcon: Color(0xFFA8AEB8),
    // Green survives here and nowhere else — it means settled, not "press me".
    paid: Color(0xFF16A34A),
    // Pushed towards orange, away from the lime brand. See the dark palette.
    dueSoon: Color(0xFFEA7317),
    overdue: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    paidTint: Color(0xFFE8F8EE),
    paidText: Color(0xFF0F7A38),
    dueSoonTint: Color(0xFFFDEEE0),
    dueSoonText: Color(0xFF8A4300),
    overdueTint: Color(0xFFFDECEC),
    overdueText: Color(0xFFB3262A),
    infoTint: Color(0xFFE8F0FE),
    infoText: Color(0xFF1A4FA0),
    textPrimary: Color(0xFF14161A),
    textSecondary: Color(0xFF5C6167),
    textTertiary: Color(0xFF666A72),
    // Near-black on the lime fill, like the navigation pill. White would be
    // about 1.4:1 and unreadable.
    textOnPrimary: Color(0xFF0F1011),
    textOnDark: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F2F4),
    surfaceInput: Color(0xFFF4F5F7),
    border: Color(0xFFE6E8EC),
    disabled: Color(0xFFE3E5E9),
    onDisabled: Color(0xFF5A5D63),
    shadowSubtle: Color(0x0A000000),
    shadowCard: Color(0x0D000000),
    shadowFloating: Color(0x1F000000),
    glow: Color(0x33D9F94A),
  );

  /// Derived from [light], since the reference design has no dark mode.
  ///
  /// Three decisions shape it:
  ///
  /// * The canvas is a near-neutral charcoal, matching the reference.s cool grey
  ///   rather than warming it.
  /// * The navigation bar becomes *lighter* than the canvas rather than darker.
  ///   In light mode a dark bar floats; in dark mode a darker bar would sink.
  /// * Shadows are much stronger. A 5%-black shadow is invisible on charcoal,
  ///   so the alpha rises to keep cards reading as lifted.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    // True black, all three stops. Not a gradient any more — a gradient from
    // black to black is three identical stops, and the honest thing is to say
    // so rather than leave two shades nobody can tell apart.
    //
    // The cards carry the depth instead: on #000000 the surface below is
    // unmistakably a raised panel, which it was not against the old #121316.
    canvasStart: Color(0xFF000000),
    canvasMid: Color(0xFF000000),
    canvasEnd: Color(0xFF000000),
    primary: Color(0xFFD9F94A),
    primaryPressed: Color(0xFFC2E035),
    primaryText: Color(0xFFD9F94A),
    primarySoft: Color(0xFF2A3007),
    // Near-black, the same bar as light mode.
    //
    // It used to be #22252A — deliberately *lighter* than the old #121316
    // canvas, so it read as floating above the page. Against a true black canvas
    // that stopped being a floating bar and became a grey slab, the lightest
    // thing on the screen after the lime pill.
    //
    // It still clears the canvas, by a hair, which is all a bar needs when its
    // own contents give it shape: the sunken circles below are lighter again,
    // and the active pill is lime.
    navSurface: Color(0xFF0A0B0D),
    navActivePill: Color(0xFFD9F94A),
    navOnActivePill: Color(0xFF0F1011),
    // Lighter than the bar, not darker. On a near-black surface a darker recess
    // is invisible — the same rule light mode follows, and the reason this one
    // had to move up when the bar moved down.
    navItemSunken: Color(0xFF1C1F24),
    navInactiveIcon: Color(0xFFA8AEB8),
    // Green survives here and nowhere else. It is no longer the brand, so it no
    // longer means "press me" — it means settled, and only that.
    paid: Color(0xFF16A34A),
    // Pushed from amber towards orange. Beside a lime brand colour the old
    // #F59E0B read as a dimmer version of the same thing, and a status has to be
    // distinguishable from a button at a glance.
    dueSoon: Color(0xFFFB8B24),
    overdue: Color(0xFFFF5A5F),
    info: Color(0xFF5B9BFF),
    paidTint: Color(0xFF14301E),
    paidText: Color(0xFF7BE8A0),
    dueSoonTint: Color(0xFF3A2109),
    dueSoonText: Color(0xFFFFB166),
    overdueTint: Color(0xFF3A1618),
    overdueText: Color(0xFFFF9A9D),
    infoTint: Color(0xFF132A45),
    infoText: Color(0xFF8FBBFF),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFB3B8C0),
    textTertiary: Color(0xFF969CA6),
    // Near-black, not white. White on lime is about 1.4:1 — illegible. This is
    // the same pairing the navigation pill has always used, and it is why that
    // pill reads cleanly while a white-on-lime button would not.
    textOnPrimary: Color(0xFF0F1011),
    textOnDark: Color(0xFFF5F5F7),
    surface: Color(0xFF161719),
    surfaceMuted: Color(0xFF212328),
    surfaceInput: Color(0xFF1C1E22),
    // Lifted from #292C31. It is the only edge a card has in dark mode now, and
    // at the old value the hairline was there in the file and not on the screen.
    border: Color(0xFF34383F),
    disabled: Color(0xFF26292E),
    onDisabled: Color(0xFF9DA3AC),
    // Heavier than before. A shadow is a shade of black, and against a black
    // canvas the old ones did nothing at all — the cards separate by being
    // lighter than their background now, which is the opposite of light mode.
    shadowSubtle: Color(0x00000000),
    shadowCard: Color(0x00000000),
    shadowFloating: Color(0x59000000),
    glow: Color(0x33D9F94A),
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
      canvasStart: mix(canvasStart, other.canvasStart),
      canvasMid: mix(canvasMid, other.canvasMid),
      canvasEnd: mix(canvasEnd, other.canvasEnd),
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
