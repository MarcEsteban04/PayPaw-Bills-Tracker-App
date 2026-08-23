import 'package:flutter/material.dart';

/// Landing screen.
///
/// **Placeholder.** It exists so the app has a route to render while the
/// architecture is being put in place. The real dashboard — built to match
/// `design/app_ref_design/app_design_reference.webp` — arrives with the design
/// system in Phase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('🐾', style: textTheme.displayMedium),
              const SizedBox(height: 8),
              Text('PayPaw', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Architecture scaffold is in place.\n'
                'The dashboard is built in Phase 2.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
