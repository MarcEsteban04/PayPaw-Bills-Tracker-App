import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/screen_placeholder.dart';

/// Obligations laid out by date.
///
/// Placeholder.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Calendar',
      icon: Icons.calendar_month_rounded,
      description:
          'A month view of what is due when, so a heavy week is visible '
          'before it arrives.',
      buildsIn: 'Sprints 44-47',
    );
  }
}
