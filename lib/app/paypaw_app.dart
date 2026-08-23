import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

/// The root widget.
///
/// Deliberately thin: it wires the router and theme together and nothing else.
/// Startup work belongs in `main()`, and screen logic belongs in its feature.
class PayPawApp extends ConsumerWidget {
  const PayPawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PayPaw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
