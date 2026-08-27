import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/supabase_providers.dart';
import '../../features/auth/presentation/controllers/auth_refresh_notifier.dart';
import '../../features/auth/presentation/controllers/current_user_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/bills/presentation/screens/add_bill_screen.dart';
import '../../features/bills/presentation/screens/bills_screen.dart';
import '../../features/bills/presentation/screens/edit_bill_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/debts/presentation/screens/add_debt_screen.dart';
import '../../features/debts/presentation/screens/debts_screen.dart';
import '../../features/debts/presentation/screens/edit_debt_screen.dart';
import '../../features/design_system/presentation/screens/components_screen.dart';
import '../../features/design_system/presentation/screens/design_system_screen.dart';
import '../../features/notifications/presentation/screens/reminder_settings_screen.dart';
import '../../features/onboarding/presentation/controllers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscriptions/presentation/screens/add_subscription_screen.dart';
import '../../features/subscriptions/presentation/screens/edit_subscription_screen.dart';
import '../../features/subscriptions/presentation/screens/subscriptions_screen.dart';
import '../shell/app_destination.dart';
import '../shell/app_shell.dart';
import 'app_page_transitions.dart';
import 'app_routes.dart';
import 'auth_guard.dart';

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
///   /settings    settings
/// /sign-in /sign-up /forgot-password     above the shell, public
/// /reset-password                        above the shell, reached by deep link
/// /design-system /components             above the shell, developer galleries
/// ```
///
/// ## Guarding
///
/// `redirect` delegates to `authRedirect` in `auth_guard.dart`. Everything but
/// the auth screens needs a session, and a signed-in user is bounced off the
/// auth screens — with `/reset-password` exempt, because a recovery session
/// signs the user in before that screen ever appears.
///
/// The tabs are branches of one shell route rather than four top-level routes so
/// that each keeps its own navigation stack: open a bill detail in Bills, switch
/// to Calendar and back, and the detail is still there.
///
/// A detail screen belongs *inside* its tab's branch, so the bottom navigation
/// stays visible while it is open. Put a route above the shell only when it
/// should cover the navigation entirely — as the design system gallery does.

/// The router's own navigator, for the few places that need a context below it
/// while living above it — `SessionExpiryListener` wraps this from inside
/// `MaterialApp`'s builder, so it has no `Overlay` of its own.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'paypaw-root-navigator',
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) => GoRouter(
    initialLocation: AppRoutes.dashboard.path,

    // Exposed so code above the navigator can still reach the root overlay.
    navigatorKey: rootNavigatorKey,

    // The bridge, not the session itself. Watching the session here would
    // rebuild the whole GoRouter on every auth change and discard the
    // navigation stack with it; a listenable lets the router stay put and
    // re-run its guard. The provider is never rebuilt, so neither is this.
    refreshListenable: ref.watch(authRefreshProvider),

    // read, not watch: the guard runs on demand, and refreshListenable is what
    // decides when. Watching here would defeat the point of the bridge.
    redirect: (_, GoRouterState state) => authRedirect(
      isBackendConfigured: ref.read(isBackendConfiguredProvider),
      session: ref.read(currentUserProvider),
      location: state.matchedLocation,
      progress: ref.read(onboardingProgressStoreProvider),
    ),
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (_, _, StatefulNavigationShell navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          _branch(AppDestination.dashboard, const DashboardScreen()),
          _branch(AppDestination.bills, const BillsScreen()),
          _branch(AppDestination.calendar, const CalendarScreen()),
          _branch(AppDestination.settings, const SettingsScreen()),
        ],
      ),
      GoRoute(
        path: AppRoutes.welcome.path,
        name: AppRoutes.welcome.routeName,
        // Fades rather than sliding: nothing preceded it, so there is no
        // direction for it to have come from.
        pageBuilder: (_, GoRouterState state) =>
            AppPageTransitions.fade(state: state, child: const WelcomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.onboarding.path,
        name: AppRoutes.onboarding.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const OnboardingScreen(),
        ),
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
        path: AppRoutes.addBill.path,
        name: AppRoutes.addBill.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const AddBillScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editBill.path,
        name: AppRoutes.editBill.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          // The id is required by the path, so a missing one is a wiring bug
          // rather than a user-facing case — hence the assertion rather than a
          // fallback screen.
          child: EditBillScreen(billId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.reminderSettings.path,
        name: AppRoutes.reminderSettings.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const ReminderSettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.subscriptions.path,
        name: AppRoutes.subscriptions.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const SubscriptionsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.addSubscription.path,
        name: AppRoutes.addSubscription.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const AddSubscriptionScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editSubscription.path,
        name: AppRoutes.editSubscription.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: EditSubscriptionScreen(
            subscriptionId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.debts.path,
        name: AppRoutes.debts.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const DebtsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.addDebt.path,
        name: AppRoutes.addDebt.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: const AddDebtScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editDebt.path,
        name: AppRoutes.editDebt.routeName,
        pageBuilder: (_, GoRouterState state) => AppPageTransitions.forward(
          state: state,
          child: EditDebtScreen(debtId: state.pathParameters['id']!),
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
