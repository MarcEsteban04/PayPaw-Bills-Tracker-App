import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Gradient tokens.
///
/// The reference design's background is not a flat colour — it is a warm peach
/// that fades diagonally towards white. Reproducing that is most of what makes
/// a screen look like the reference, so it is a token rather than a per-screen
/// decoration.
abstract final class AppGradients {
  /// The app background. Applied once per screen, behind everything.
  static const LinearGradient canvas = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.canvasPeach,
      AppColors.canvasCream,
      AppColors.canvasWhite,
    ],
    stops: <double>[0, 0.45, 1],
  );

  /// Fill for the primary CTA. A shallow gradient, not a colour wash — the
  /// reference's button reads almost flat, with the lighter tone at the top.
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFF7F38), AppColors.primary],
  );
}
