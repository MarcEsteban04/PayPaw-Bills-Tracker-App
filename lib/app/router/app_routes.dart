/// Every route in PayPaw, in one place.
///
/// Paths and names live together so a screen is never navigated to with a
/// hand-written string. Use `context.goNamed(AppRoutes.home.routeName)` rather
/// than `context.go('/')`, so renaming a path cannot break a call site.
///
/// The member is called `routeName` rather than `name` because `name` is already
/// taken by Dart's implicit enum getter.
enum AppRoutes {
  /// Dashboard — the app's landing screen.
  home(path: '/', routeName: 'home');

  const AppRoutes({required this.path, required this.routeName});

  /// URL path used by go_router, and by Android deep links.
  final String path;

  /// Stable identifier used for named navigation.
  final String routeName;
}
