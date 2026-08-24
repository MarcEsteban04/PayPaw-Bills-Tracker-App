/// Every route in PayPaw, in one place.
///
/// Paths and names live together so a screen is never navigated to with a
/// hand-written string. Use `context.goNamed(AppRoutes.bills.routeName)` rather
/// than `context.go('/bills')`, so renaming a path cannot break a call site.
///
/// The member is called `routeName` rather than `name` because `name` is already
/// taken by Dart's implicit enum getter.
enum AppRoutes {
  // --- Primary destinations, one per bottom-navigation tab -------------------

  /// Overview: what is owed, and what falls due next.
  dashboard(path: '/', routeName: 'dashboard'),

  /// The full list of obligations, searchable and filterable.
  bills(path: '/bills', routeName: 'bills'),

  /// The same obligations laid out by date.
  calendar(path: '/calendar', routeName: 'calendar'),

  /// Account, settings, and the occasionally-used feature areas.
  profile(path: '/profile', routeName: 'profile'),

  // --- Authentication -------------------------------------------------------

  /// Sign in. Above the shell, because an auth screen should not show the app's
  /// navigation behind it.
  signIn(path: '/sign-in', routeName: 'sign-in'),

  /// Registration.
  signUp(path: '/sign-up', routeName: 'sign-up'),

  /// Requests a password reset email.
  forgotPassword(path: '/forgot-password', routeName: 'forgot-password'),

  /// Sets a new password using the recovery session a reset link creates.
  /// Reached automatically by the deep link, not from a menu.
  resetPassword(path: '/reset-password', routeName: 'reset-password'),

  // --- Developer tools ------------------------------------------------------

  /// Gallery of every design token. Reached from Profile; not a user
  /// destination.
  designSystem(path: '/design-system', routeName: 'design-system'),

  /// Gallery of every reusable component, live. Also reached from Profile.
  components(path: '/components', routeName: 'components');

  const AppRoutes({required this.path, required this.routeName});

  /// URL path used by go_router, and by Android deep links.
  final String path;

  /// Stable identifier used for named navigation.
  final String routeName;
}
