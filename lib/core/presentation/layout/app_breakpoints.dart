import 'package:flutter/widgets.dart';

/// How much horizontal room a screen has to work with.
///
/// Named after Material's window size classes rather than invented device
/// categories, because "phone" and "tablet" stop meaning anything once a foldable
/// is half-open or an app is running in a split-screen pane. What matters is the
/// width the app was handed.
enum AppWindowSize {
  /// Under 600dp — a phone in portrait, or a narrow split-screen pane. The
  /// design's baseline.
  compact,

  /// 600 to 839dp — a small tablet, a large phone in landscape, an unfolded
  /// foldable.
  medium,

  /// 840dp and up — a tablet in landscape, or a desktop window.
  expanded;

  /// Whether this is the narrow case the reference design was drawn for.
  bool get isCompact => this == AppWindowSize.compact;

  /// Whether there is room to stop stretching content across the full width.
  bool get isWide => this != AppWindowSize.compact;
}

/// Width thresholds, and the maximum width content is allowed to occupy.
abstract final class AppBreakpoints {
  /// Below this, treat the window as [AppWindowSize.compact].
  static const double medium = 600;

  /// At or above this, treat the window as [AppWindowSize.expanded].
  static const double expanded = 840;

  /// The widest a column of content may get.
  ///
  /// PayPaw is a phone app. Letting a bill list stretch to 1200dp does not use
  /// the space, it just makes every row a long horizontal scan between a name on
  /// the far left and an amount on the far right. Content stays a comfortable
  /// column and centres itself instead.
  static const double maxContentWidth = 560;

  /// The widest the floating bottom navigation may get, for the same reason —
  /// four destinations spread across a whole tablet are further apart than a
  /// thumb wants to travel.
  static const double maxNavWidth = 480;

  /// Below this the bottom navigation drops its selected label and shows icons
  /// only. Measured against the navigation bar's own width, not the screen's.
  static const double navLabelMinWidth = 300;

  /// Classifies a width.
  static AppWindowSize of(double width) => switch (width) {
    < medium => AppWindowSize.compact,
    < expanded => AppWindowSize.medium,
    _ => AppWindowSize.expanded,
  };
}

/// Convenience access to the current window size.
extension AppLayoutContext on BuildContext {
  /// The window size class for this context's width.
  ///
  /// Reads `MediaQuery.sizeOf`, so a widget using it rebuilds when the window
  /// changes — a rotation, a split-screen resize, a foldable being opened.
  AppWindowSize get windowSize =>
      AppBreakpoints.of(MediaQuery.sizeOf(this).width);
}
