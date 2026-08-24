/// Every bundled asset path, in one place.
///
/// An asset path is a string the compiler cannot check: a typo is a runtime
/// exception on the screen that needed the image. Naming them here means a
/// renamed file breaks the build instead, and `pubspec.yaml` can be compared
/// against this file by eye.
abstract final class AppAssets {
  /// The PayPaw wordmark and paw. Square, 1254×1254.
  static const String logo = 'assets/images/paypaw_logo.png';

  /// The welcome screen background. Portrait, 1024×1536.
  static const String welcomeIllustration =
      'assets/images/welcome_illustration.png';
}
