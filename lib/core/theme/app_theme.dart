import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles an [AppPalette] into a Material [ThemeData].
///
/// The goal is that a plain `ElevatedButton`, `TextField`, or `Card` already
/// looks like the reference design without a single style argument at the call
/// site. Anything that needs styling in more than one place belongs here rather
/// than in a widget.
///
/// Component elevation is kept at zero throughout: PayPaw paints its own soft
/// shadows from the palette, because Material's default elevation shadows are
/// tighter and darker than the reference's.
///
/// Both themes are built by the same [of] function from different palettes, so a
/// component styled once is styled for both. That is the whole point of the
/// palette being a theme extension: there is no second copy of this file for
/// dark mode to fall out of step with.
abstract final class AppTheme {
  /// Minimum tappable size. Below 48dp a target fails Material's accessibility
  /// guidance regardless of how small the icon looks in the design.
  static const double minTapTarget = 48;

  /// Height of a primary button.
  ///
  /// 48 to match the reference, whose pill buttons are shorter than the previous
  /// design.s. Still at Material.s minimum tap target, so nothing is lost.
  static const double buttonHeight = 48;

  /// The light theme, sampled from the reference design.
  static ThemeData get light => of(AppPalette.light);

  /// The dark theme.
  static ThemeData get dark => of(AppPalette.dark);

  /// Builds a theme from [palette].
  static ThemeData of(AppPalette palette) {
    final TextTheme textTheme = AppTypography.textTheme(palette);

    return ThemeData(
      brightness: palette.brightness,
      colorScheme: _colorScheme(palette),
      textTheme: textTheme,

      // The palette travels with the theme, which is how `context.colors` works.
      extensions: <ThemeExtension<dynamic>>[palette],

      // Transparent so the canvas gradient painted once in PayPawApp shows
      // through every route. A screen that needs an opaque background must set
      // it explicitly, which is the rarer case in this design.
      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: _appBarTheme(palette, textTheme),
      cardTheme: _cardTheme(palette),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(palette, textTheme),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(palette, textTheme),
      ),
      outlinedButtonTheme: _outlinedButtonTheme(palette, textTheme),
      textButtonTheme: _textButtonTheme(palette, textTheme),
      iconButtonTheme: _iconButtonTheme(palette),
      inputDecorationTheme: _inputDecorationTheme(palette, textTheme),
      chipTheme: _chipTheme(palette, textTheme),
      tabBarTheme: _tabBarTheme(palette, textTheme),
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: true,
        dragHandleColor: palette.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.panel),
      ),
      // Not on Sprint 8's component list, but a confirmation dialog needs
      // somewhere to report what it did, and an unthemed snack bar is the one
      // Material default that would look pasted in from another app.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.brightness == Brightness.light
            ? palette.navSurface
            : palette.surfaceMuted,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.brightness == Brightness.light
              ? palette.textOnDark
              : palette.textPrimary,
        ),
        actionTextColor: palette.navActivePill,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.input),
        elevation: 0,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
        linearTrackColor: palette.surfaceMuted,
        circularTrackColor: palette.surfaceMuted,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Colour scheme
  // ---------------------------------------------------------------------------

  /// Built member by member rather than with `ColorScheme.fromSeed`, because a
  /// seed generates its own tonal palette and would quietly override the colours
  /// sampled from the reference.
  static ColorScheme _colorScheme(AppPalette palette) => ColorScheme(
    brightness: palette.brightness,
    primary: palette.primary,
    onPrimary: palette.textOnPrimary,
    primaryContainer: palette.primarySoft,
    onPrimaryContainer: palette.primaryText,
    secondary: palette.navSurface,
    onSecondary: palette.textOnDark,
    secondaryContainer: palette.surfaceMuted,
    onSecondaryContainer: palette.textPrimary,
    tertiary: palette.paid,
    onTertiary: palette.textOnPrimary,
    error: palette.overdue,
    onError: palette.textOnPrimary,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    surfaceContainerLowest: palette.surface,
    surfaceContainerLow: palette.canvasEnd,
    surfaceContainer: palette.canvasMid,
    surfaceContainerHigh: palette.surfaceMuted,
    surfaceContainerHighest: palette.surfaceInput,
    outline: palette.border,
    outlineVariant: palette.border,
    shadow: palette.shadowFloating,
    scrim: const Color(0x66000000),
    inverseSurface: palette.textPrimary,
    onInverseSurface: palette.surface,
  );

  // ---------------------------------------------------------------------------
  // Component themes
  // ---------------------------------------------------------------------------

  /// Flat and transparent. The reference has no app bar surface — its header sits
  /// directly on the page, alongside a greeting and an avatar.
  static AppBarTheme _appBarTheme(AppPalette palette, TextTheme textTheme) =>
      AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: palette.textPrimary),
      );

  /// Softly rounded and flat. Shadows are painted by the widget from the
  /// palette, so cards share one shadow language with non-card surfaces.
  static CardThemeData _cardTheme(AppPalette palette) => CardThemeData(
    color: palette.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
    clipBehavior: Clip.antiAlias,
  );

  /// The primary CTA: a green pill, flat, full width where it is used.
  ///
  /// Shared by `ElevatedButton` and `FilledButton` so the two are
  /// indistinguishable — there is only one primary button in this design.
  static ButtonStyle _primaryButtonStyle(
    AppPalette palette,
    TextTheme textTheme,
  ) => ButtonStyle(
    // Resolvers rather than flat values, so a disabled button reads as disabled
    // instead of as a primary action that ignores taps.
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? palette.disabled
          : palette.primary,
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? palette.onDisabled
          : palette.textOnPrimary,
    ),
    overlayColor: WidgetStatePropertyAll<Color>(palette.primaryPressed),
    elevation: const WidgetStatePropertyAll<double>(0),
    minimumSize: const WidgetStatePropertyAll<Size>(
      Size.fromHeight(buttonHeight),
    ),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
    ),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(borderRadius: AppRadii.round),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle?>(
      textTheme.labelLarge?.copyWith(color: palette.textOnPrimary),
    ),
  );

  /// Secondary action: the primary button's geometry with a hairline outline
  /// instead of a fill, so the two sit side by side without jumping.
  static OutlinedButtonThemeData _outlinedButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) => OutlinedButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(palette.textPrimary),
      side: WidgetStatePropertyAll<BorderSide>(
        BorderSide(color: palette.border),
      ),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size.fromHeight(buttonHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadii.round),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
    ),
  );

  /// Inline action. Uses the text-safe green, because this is the brand colour as
  /// text on a surface rather than as a fill.
  static TextButtonThemeData _textButtonTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) => TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(palette.primaryText),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(minTapTarget, minTapTarget),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(
        textTheme.labelLarge?.copyWith(color: palette.primaryText),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadii.input),
      ),
    ),
  );

  static IconButtonThemeData _iconButtonTheme(AppPalette palette) =>
      IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll<Color>(palette.textPrimary),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(minTapTarget, minTapTarget),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
        ),
      );

  /// Filled, borderless fields: the reference's search field and form inputs are
  /// a soft fill with no visible outline until focus.
  static InputDecorationTheme _inputDecorationTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) => InputDecorationTheme(
    filled: true,
    fillColor: palette.surfaceInput,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    hintStyle: textTheme.bodyMedium?.copyWith(color: palette.textTertiary),
    labelStyle: textTheme.bodyMedium,
    floatingLabelStyle: textTheme.labelMedium?.copyWith(
      color: palette.primaryText,
    ),
    errorStyle: textTheme.bodySmall?.copyWith(color: palette.overdueText),
    prefixIconColor: palette.textTertiary,
    suffixIconColor: palette.textTertiary,
    border: _inputBorder(),
    enabledBorder: _inputBorder(),
    disabledBorder: _inputBorder(),
    focusedBorder: _inputBorder(color: palette.primary, width: 1.5),
    errorBorder: _inputBorder(color: palette.overdue),
    focusedErrorBorder: _inputBorder(color: palette.overdue, width: 1.5),
  );

  /// One border builder for all input states, so only the parts that actually
  /// differ between states are written out above.
  static OutlineInputBorder _inputBorder({Color? color, double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadii.input,
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  /// The reference's meta pills: light fill, tight radius, small muted label,
  /// no border.
  static ChipThemeData _chipTheme(AppPalette palette, TextTheme textTheme) =>
      ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.primarySoft,
        disabledColor: palette.disabled,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: palette.primaryText,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chip),
        showCheckmark: false,
      );

  /// The underline tab row: a green bar under the active label, no pill, no
  /// background, no divider.
  static TabBarThemeData _tabBarTheme(
    AppPalette palette,
    TextTheme textTheme,
  ) => TabBarThemeData(
    labelColor: palette.primaryText,
    unselectedLabelColor: palette.textTertiary,
    labelStyle: textTheme.titleSmall?.copyWith(color: palette.primaryText),
    unselectedLabelStyle: textTheme.titleSmall?.copyWith(
      color: palette.textTertiary,
      fontWeight: FontWeight.w500,
    ),
    indicatorSize: TabBarIndicatorSize.label,
    indicator: UnderlineTabIndicator(
      borderSide: BorderSide(color: palette.primary, width: 2.5),
      insets: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    ),
    dividerColor: Colors.transparent,
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  );
}
