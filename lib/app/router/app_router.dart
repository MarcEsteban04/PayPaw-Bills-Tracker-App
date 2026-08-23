import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_screen.dart';
import 'app_routes.dart';

/// PayPaw's navigation graph.
///
/// The router is a provider rather than a global so that it can depend on other
/// providers later — auth state redirects in Sprints 11-15, and notification
/// deep links in Sprints 39-43 — without any of that being retro-fitted.
final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) => GoRouter(
    initialLocation: AppRoutes.home.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home.path,
        name: AppRoutes.home.routeName,
        builder: (_, _) => const HomeScreen(),
      ),
    ],
  ),
);
