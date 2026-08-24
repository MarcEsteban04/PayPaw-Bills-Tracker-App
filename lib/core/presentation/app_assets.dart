/// Every bundled asset path, in one place.
///
/// An asset path is a string the compiler cannot check: a typo is a runtime
/// exception on the screen that needed the image. Naming them here means a
/// renamed file breaks the build instead, and `pubspec.yaml` can be compared
/// against this file by eye.
abstract final class AppAssets {
  /// The PayPaw mascot with a wallet, a calendar and a bell. Square, 1254×1254,
  /// with a **transparent background**.
  ///
  /// That transparency is why this is the only illustration the app ships. The
  /// welcome screen previously used a 1024×1536 version of the same scene drawn
  /// on black, which forced a dark card to sit behind it on an otherwise light
  /// screen. Its background could not be removed in code either: measuring it
  /// showed only 31% of the frame is near-black and the glow reaches the edges,
  /// so it is a gradient rather than a key colour, and any threshold leaves
  /// either a hard ring or a gold haze. The source is kept at
  /// `design/source/welcome_illustration_on_black.png` and is no longer bundled.
  ///
  /// Detailed for a small mark — at 40dp the calendar and bell turn to mush. A
  /// simplified glyph would read better in the auth header, and is worth drawing
  /// alongside the launcher icons.
  static const String logo = 'assets/images/paypaw_logo.png';
}
