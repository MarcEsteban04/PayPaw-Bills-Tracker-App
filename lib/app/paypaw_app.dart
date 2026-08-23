import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_gradients.dart';
import '../core/theme/app_theme.dart';
import 'router/app_router.dart';

/// The root widget.
///
/// Deliberately thin: it wires the router, the theme, and the canvas behind
/// them. Startup work belongs in `main()`, and screen logic belongs in its
/// feature.
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
      builder: _buildCanvas,
    );
  }

  /// Paints the reference design's peach gradient once, behind every route.
  ///
  /// Doing it here rather than per screen is what stops the canvas being
  /// re-declared in every `build` method and drifting apart over 85 sprints. It
  /// works because the theme sets `scaffoldBackgroundColor` to transparent — a
  /// screen that genuinely needs an opaque background has to say so.
  static Widget _buildCanvas(BuildContext context, Widget? child) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.canvas),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
