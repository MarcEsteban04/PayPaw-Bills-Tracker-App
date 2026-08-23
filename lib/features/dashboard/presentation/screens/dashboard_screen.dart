import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/screen_placeholder.dart';

/// The dashboard — PayPaw's landing screen.
///
/// Placeholder. The real dashboard reproduces the reference design's overview
/// panel: a progress arc for the month, the total due, and the upcoming bills
/// list under status tabs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Dashboard',
      icon: Icons.insights_rounded,
      description:
          'Your month at a glance: how much is due, how much is paid, and '
          'what falls due next.',
      buildsIn: 'Sprints 34-38',
    );
  }
}
