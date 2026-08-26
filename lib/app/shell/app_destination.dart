import 'package:flutter/material.dart';

import '../router/app_routes.dart';

/// The app's primary destinations — the four tabs in the bottom navigation.
///
/// Four, because the reference navigation has four. PayPaw has more feature
/// areas than that (subscriptions, debts, analytics, the AI assistant), so the
/// rule applied here is: a tab is for something opened *daily*. Everything else
/// is reached from inside a tab.
///
/// * **Dashboard** — what do I owe, and what is due next.
/// * **Bills** — the full list, searched and filtered.
/// * **Calendar** — the same obligations laid out by date.
/// * **Profile** — account, settings, and the feature areas used occasionally.
///
/// Subscriptions and debts live under Bills; analytics and streaks live under
/// Dashboard. Adding a fifth tab means adding a fifth here and nowhere else, but
/// it also means the nav no longer matches the reference.
///
/// Order is display order.
enum AppDestination {
  dashboard(
    route: AppRoutes.dashboard,
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  bills(
    route: AppRoutes.bills,
    label: 'Bills',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  calendar(
    route: AppRoutes.calendar,
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
  ),
  settings(
    route: AppRoutes.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  );

  const AppDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// The route this destination shows.
  final AppRoutes route;

  /// Text shown in the active pill, and the accessibility label for all states.
  final String label;

  /// Icon when this destination is not selected.
  final IconData icon;

  /// Icon when this destination is selected. Filled rather than outlined, which
  /// is what makes the active state readable at a glance even before the pill
  /// colour registers.
  final IconData selectedIcon;
}
