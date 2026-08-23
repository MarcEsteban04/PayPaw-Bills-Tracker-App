import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_theme.dart';

/// Pumps a single widget inside PayPaw's real theme.
///
/// Using the real theme rather than a bare `MaterialApp` matters: most of what
/// these components look like comes from `AppTheme`, so testing them without it
/// would test a widget that never ships.
///
/// Pass `settle: false` for anything containing a continuous animation — a
/// spinner or a skeleton pulse. `pumpAndSettle` waits for the tree to go quiet,
/// and an animation that repeats forever never does, so it times out instead of
/// failing usefully.
Future<void> pumpInApp(
  WidgetTester tester,
  Widget child, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
