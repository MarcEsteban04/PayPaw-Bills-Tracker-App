import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles PayPaw's tokens into a Material [ThemeData].
///
/// The goal is that a plain `ElevatedButton`, `TextField`, or `Card` already
/// looks like the reference design without a single style argument at the call
/// site. Anything that needs styling in more than one place belongs here rather
/// than in a widget.
///
/// Component elevation is kept at zero throughout: PayPaw paints its own soft
/// shadows from `AppShadows`, because Material's default elevation shadows are
/// tighter and darker than the reference's.
///
/// Dark mode arrives in Sprint 10. Until then there is one theme and it is
/// light, matching the reference, which is light-only.
abstract final class AppTheme {
  /// Minimum tappable size. Below 48dp a target fails Material's accessibility
  /// guidance regardless of how small the icon looks in the design.
  static const double minTapTarget = 48;

  /// Height of a primary button. The reference's CTA is taller than Material's
  /// 48dp default.
  static const double buttonHeight = 52;

  /// The light theme.
  static ThemeData get light {
    final TextTheme textTheme = AppTypography.textTheme;

    return ThemeData(
      colorScheme: _colorScheme,
      textTheme: textTheme,

      // Transparent so the canvas gradient painted once in PayPawApp shows
      // through every route. A screen that needs an opaque background must set
      // it explicitly, which is the rarer case in this design.
      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: _appBarTheme(textTheme),
      cardTheme: _cardTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _primaryButtonStyle(textTheme),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _primaryButtonStyle(textTheme),
      ),
      outlinedButtonTheme: _outlinedButtonTheme(textTheme),
      textButtonTheme: _textButtonTheme(textTheme),
      iconButtonTheme: _iconButtonTheme,
      inputDecorationTheme: _inputDecorationTheme(textTheme),
      chipTheme: _chipTheme(textTheme),
      tabBarTheme: _tabBarTheme(textTheme),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.panel),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Colour scheme
  // ---------------------------------------------------------------------------

  /// Built member by member rather than with `ColorScheme.fromSeed`, because a
  /// seed generates its own tonal palette and would quietly override the
  /// colours sampled from the reference.
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textOnPrimary,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryText,
    secondary: AppColors.navSurface,
    onSecondary: AppColors.textOnDark,
    secondaryContainer: AppColors.surfaceMuted,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.paid,
    onTertiary: AppColors.textOnPrimary,
    error: AppColors.overdue,
    onError: AppColors.textOnPrimary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.canvasWhite,
    surfaceContainer: AppColors.canvasCream,
    surfaceContainerHigh: AppColors.surfaceMuted,
    surfaceContainerHighest: AppColors.surfaceInput,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    shadow: Color(0x1A000000),
    scrim: Color(0x66000000),
    inverseSurface: AppColors.navSurface,
    onInverseSurface: AppColors.textOnDark,
  );

  // ---------------------------------------------------------------------------
  // Component themes
  // ---------------------------------------------------------------------------

  /// Flat and transparent, because the reference has no app bar surface: the
  /// title sits directly on the peach canvas.
  static AppBarTheme _appBarTheme(TextTheme textTheme) => AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: textTheme.headlineMedium,
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
  );

  /// White, softly rounded and flat. Shadows are painted by the widget using
  /// `AppShadows`, so cards share one shadow language with non-card surfaces.
  static const CardThemeData _cardTheme = CardThemeData(
    color: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
    clipBehavior: Clip.antiAlias,
  );

  /// The primary CTA: an orange pill, flat, full width where it is used.
  ///
  /// Shared by `ElevatedButton` and `FilledButton` so the two are
  /// indistinguishable — there is only one primary button in this design.
  static ButtonStyle _primaryButtonStyle(TextTheme textTheme) => ButtonStyle(
    backgroundColor: const WidgetStatePropertyAll<Color>(AppColors.primary),
    foregroundColor: const WidgetStatePropertyAll<Color>(
      AppColors.textOnPrimary,
    ),
    overlayColor: const WidgetStatePropertyAll<Color>(AppColors.primaryPressed),
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
      textTheme.labelLarge?.copyWith(color: AppColors.textOnPrimary),
    ),
  );

  /// Secondary action: the primary button's geometry with a hairline outline
  /// instead of a fill, so the two sit side by side without jumping.
  static OutlinedButtonThemeData _outlinedButtonTheme(TextTheme textTheme) =>
      OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(
            AppColors.textPrimary,
          ),
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.border),
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

  /// Inline action. Uses the darkened orange, because this is orange as text on
  /// a light surface.
  static TextButtonThemeData _textButtonTheme(TextTheme textTheme) =>
      TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll<Color>(
            AppColors.primaryText,
          ),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(minTapTarget, minTapTarget),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(
            textTheme.labelLarge?.copyWith(color: AppColors.primaryText),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadii.input),
          ),
        ),
      );

  static const IconButtonThemeData _iconButtonTheme = IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(AppColors.textPrimary),
      minimumSize: WidgetStatePropertyAll<Size>(
        Size(minTapTarget, minTapTarget),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(CircleBorder()),
    ),
  );

  /// Filled, borderless fields: the reference's search field and form inputs are
  /// a soft grey fill with no visible outline until focus.
  static InputDecorationTheme _inputDecorationTheme(TextTheme textTheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primaryText,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppColors.overdue),
        prefixIconColor: AppColors.textTertiary,
        suffixIconColor: AppColors.textTertiary,
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        disabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: AppColors.primary, width: 1.5),
        errorBorder: _inputBorder(color: AppColors.overdue),
        focusedErrorBorder: _inputBorder(color: AppColors.overdue, width: 1.5),
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
  static ChipThemeData _chipTheme(TextTheme textTheme) => ChipThemeData(
    backgroundColor: AppColors.surfaceMuted,
    selectedColor: AppColors.primarySoft,
    disabledColor: AppColors.disabled,
    labelStyle: textTheme.labelMedium,
    secondaryLabelStyle: textTheme.labelMedium?.copyWith(
      color: AppColors.primaryText,
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

  /// The underline tab row from the reference: an orange bar under the active
  /// label, no pill, no background, no divider.
  static TabBarThemeData _tabBarTheme(TextTheme textTheme) => TabBarThemeData(
    labelColor: AppColors.primaryText,
    unselectedLabelColor: AppColors.textTertiary,
    labelStyle: textTheme.titleSmall?.copyWith(color: AppColors.primaryText),
    unselectedLabelStyle: textTheme.titleSmall?.copyWith(
      color: AppColors.textTertiary,
      fontWeight: FontWeight.w500,
    ),
    indicatorSize: TabBarIndicatorSize.label,
    indicator: const UnderlineTabIndicator(
      borderSide: BorderSide(color: AppColors.primary, width: 2.5),
      insets: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    ),
    dividerColor: Colors.transparent,
    overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  );
}
