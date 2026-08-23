import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/screen_placeholder.dart';

/// The full list of financial obligations.
///
/// Placeholder. Subscriptions and debts are reached from here rather than from
/// their own tabs — see `AppDestination` for why.
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Bills',
      icon: Icons.receipt_long_rounded,
      description:
          'Every bill, subscription and debt in one list, searchable and '
          'filterable by category, status and due date.',
      buildsIn: 'Sprints 21-28',
    );
  }
}
