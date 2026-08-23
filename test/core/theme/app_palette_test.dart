import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_palette.dart';

/// WCAG contrast ratio between two opaque colours.
///
/// `Color.computeLuminance` is Flutter's implementation of WCAG relative
/// luminance, so this is the real formula rather than an approximation.
double contrastRatio(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  final double lighter = math.max(first, second);
  final double darker = math.min(first, second);

  return (lighter + 0.05) / (darker + 0.05);
}

/// Contrast tests for both palettes.
///
/// The design docs claim every text colour clears WCAG AA. Claims in a document
/// rot; this checks them. It exists because an earlier sprint nearly shipped a
/// lime accent at 1.1:1 on white, and because hand-checking 20 pairs across two
/// themes is exactly the sort of thing a person does once and never again.
///
/// The known exception is white-on-primary, which sits near 3:1 and is allowed
/// only for large text — it is asserted at the large-text threshold rather than
/// quietly skipped.
void main() {
  /// AA for body text.
  const double aaNormal = 4.5;

  /// AA for large text, and for icons and other non-text contrast.
  const double aaLarge = 3;

  for (final (String name, AppPalette palette) in <(String, AppPalette)>[
    ('light', AppPalette.light),
    ('dark', AppPalette.dark),
  ]) {
    group('$name palette', () {
      void expectContrast(
        String description,
        Color foreground,
        Color background, {
        double minimum = aaNormal,
      }) {
        final double ratio = contrastRatio(foreground, background);
        expect(
          ratio,
          greaterThanOrEqualTo(minimum),
          reason:
              '$description is ${ratio.toStringAsFixed(2)}:1, '
              'below the required $minimum:1',
        );
      }

      test('text on surface clears AA', () {
        expectContrast(
          'textPrimary on surface',
          palette.textPrimary,
          palette.surface,
        );
        expectContrast(
          'textSecondary on surface',
          palette.textSecondary,
          palette.surface,
        );
        expectContrast(
          'textTertiary on surface',
          palette.textTertiary,
          palette.surface,
        );
        expectContrast(
          'primaryText on surface',
          palette.primaryText,
          palette.surface,
        );
      });

      test('text on muted surfaces clears AA', () {
        expectContrast(
          'textSecondary on surfaceMuted',
          palette.textSecondary,
          palette.surfaceMuted,
        );
        expectContrast(
          'textTertiary on surfaceMuted',
          palette.textTertiary,
          palette.surfaceMuted,
        );
        expectContrast(
          'onDisabled on disabled',
          palette.onDisabled,
          palette.disabled,
        );
      });

      test('every status tint clears AA with its own text colour', () {
        for (final AppStatusTone tone in AppStatusTone.values) {
          expectContrast(
            '${tone.name} text on ${tone.name} tint',
            palette.statusText(tone),
            palette.statusTint(tone),
          );
        }
      });

      test('the navigation bar clears AA', () {
        expectContrast(
          'navOnActivePill on navActivePill',
          palette.navOnActivePill,
          palette.navActivePill,
        );
        expectContrast(
          'textOnDark on navSurface',
          palette.textOnDark,
          palette.navSurface,
        );
        // An icon is non-text content, so 3:1 is the bar.
        expectContrast(
          'navInactiveIcon on navItemSunken',
          palette.navInactiveIcon,
          palette.navItemSunken,
          minimum: aaLarge,
        );
      });

      test('white on primary clears the large-text threshold', () {
        // Documented and deliberate: the brand orange is not adjusted to reach
        // 4.5:1, so button labels stay semibold at 15pt and no smaller.
        expectContrast(
          'textOnPrimary on primary',
          palette.textOnPrimary,
          palette.primary,
          minimum: aaLarge,
        );
      });
    });
  }

  group('the two palettes are actually different', () {
    test('surfaces and canvas differ', () {
      expect(AppPalette.light.surface, isNot(AppPalette.dark.surface));
      expect(AppPalette.light.canvasPeach, isNot(AppPalette.dark.canvasPeach));
      expect(AppPalette.light.textPrimary, isNot(AppPalette.dark.textPrimary));
    });

    test('the lime navigation accent is shared', () {
      // It is the brand's navigation accent and it works on either background,
      // so it is deliberately the same in both themes.
      expect(AppPalette.light.navActivePill, AppPalette.dark.navActivePill);
    });

    test('the navigation bar inverts relative to the canvas', () {
      // Light mode: a dark bar floats above a light page. Dark mode: the bar has
      // to be lighter than the page, or it sinks into it.
      expect(
        AppPalette.light.navSurface.computeLuminance(),
        lessThan(AppPalette.light.canvasCream.computeLuminance()),
      );
      expect(
        AppPalette.dark.navSurface.computeLuminance(),
        greaterThan(AppPalette.dark.canvasCream.computeLuminance()),
      );
    });
  });

  group('lerp', () {
    test('interpolates rather than snapping at the midpoint', () {
      final AppPalette midway = AppPalette.light.lerp(AppPalette.dark, 0.5);

      expect(midway.surface, isNot(AppPalette.light.surface));
      expect(midway.surface, isNot(AppPalette.dark.surface));
    });

    test('returns the endpoints exactly', () {
      expect(
        AppPalette.light.lerp(AppPalette.dark, 0).surface,
        AppPalette.light.surface,
      );
      expect(
        AppPalette.light.lerp(AppPalette.dark, 1).surface,
        AppPalette.dark.surface,
      );
    });
  });
}
