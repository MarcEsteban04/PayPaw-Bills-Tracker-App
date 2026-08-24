import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/bills/presentation/screens/bills_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/design_system/presentation/screens/components_screen.dart';
import '../../features/design_system/presentation/screens/design_system_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../shell/app_destination.dart';
import '../shell/app_shell.dart';
import 'app_page_transitions.dart';
import 'app_routes.dart';

/// PayPaw's navigation graph.
///
/// The router is a provider rather than a global so that it can depend on other
/// providers later — auth state redirects in Sprints 11-15, and notification
/// deep links in Sprints 39-43 — without any of that being retro-fitted.
///
/// ## Hierarchy
///
/// ```
/// StatefulShellRoute.indexedStack        the four tabs, each with its own stack
///   /            dashboard
///   /bills       bills
///   /calendar    calendar
///   /profile     profile
/// /design-system                         above the shell, covers the nav bar
/// ```
///
/// The tabs are branches of one shell route rather than four top-level routes so
/// that each keeps its own navigation stack: open a bill detail in Bills, switch
/// to Calendar and back, and the detail is still there.
///
/// A detail screen belongs *inside* its tab's branch, so the bottom navigation
/// stays visible while it is open. Put a route above the shell only when it
/// should cover the navigation entirely — as the design system gallery does.
final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) => GoRouter(
    initialLocation: AppRoutes.dashboard.path,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          _branch(AppDestination.dashboard, const DashboardScreen()),
          _branch(AppDestination.bills, const BillsScreen()),
          _branch(AppDestination.calendar, const CalendarScreen()),
          _branch(AppDestination.profile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.signIn.path,
        name: AppRoutes.signIn.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const SignInScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp.path,
        name: AppRoutes.signUp.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const SignUpScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword.path,
        name: AppRoutes.forgotPassword.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPassword.path,
        name: AppRoutes.resetPassword.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.fade(
          state: state,
          child: const ResetPasswordScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.designSystem.path,
        name: AppRoutes.designSystem.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const DesignSystemScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.components.path,
        name: AppRoutes.components.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const ComponentsScreen(),
        ),
      ),
    ],
  ),
);

/// One tab. Written as a helper so a branch cannot be wired to the wrong route:
/// the path and name both come from the destination.
///
/// Nested detail routes for a tab go in this branch's `routes`, below its root.
StatefulShellBranch _branch(AppDestination destination, Widget screen) {
  return StatefulShellBranch(
    routes: <RouteBase>[
      GoRoute(
        path: destination.route.path,
        name: destination.route.routeName,
        builder: (_, _) => screen,
      ),
    ],
  );
}
