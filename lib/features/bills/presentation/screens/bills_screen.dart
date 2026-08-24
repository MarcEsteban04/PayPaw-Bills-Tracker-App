import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/screen_placeholder.dart';
import '../../../../core/theme/app_spacing.dart';

/// The full list of financial obligations.
///
/// Still a placeholder — the list itself is Sprint 28. What is real is the button:
/// Sprint 23 built the add-bill form, and a form with no way in is a form nobody
/// has used. Reached from here rather than from the dashboard because this is the
/// screen a bill belongs to; the dashboard gets its own quick action in Sprint 37.
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const ScreenPlaceholder(
        title: 'Bills',
        icon: Icons.receipt_long_rounded,
        description:
            'Every bill, subscription and debt in one list, searchable and '
            'filterable by category, status and due date.',
        buildsIn: 'Sprints 21-28',
      ),
      floatingActionButton: Padding(
        // The navigation bar floats over content, so the button has to clear it
        // or it sits under the pill.
        padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
        child: FloatingActionButton.extended(
          onPressed: () => context.pushNamed(AppRoutes.addBill.routeName),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add bill'),
        ),
      ),
    );
  }
}
