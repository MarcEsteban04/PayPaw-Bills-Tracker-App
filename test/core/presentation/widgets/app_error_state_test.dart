import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/core/presentation/widgets/app_error_state.dart';

import '../../../helpers/pump_app.dart';

/// AppErrorState is the boundary between thrown errors and what a user reads,
/// so these tests are really about one rule: our messages get shown, anything
/// else does not.
void main() {
  testWidgets('shows the exception own user message', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      const AppErrorState(error: NetworkException(debugMessage: 'SocketError')),
    );

    expect(
      find.text('No internet connection. Check your network and try again.'),
      findsOneWidget,
    );
    // The debug detail must never reach the screen.
    expect(find.textContaining('SocketError'), findsNothing);
  });

  testWidgets('uses a generic message for a foreign error', (
    WidgetTester tester,
  ) async {
    await pumpInApp(
      tester,
      AppErrorState(error: StateError('index out of range at line 42')),
    );

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    // A raw toString() is not fit to show a user, and can leak internals.
    expect(find.textContaining('index out of range'), findsNothing);
  });

  testWidgets('offers retry only when a handler is given', (
    WidgetTester tester,
  ) async {
    await pumpInApp(tester, const AppErrorState(error: ServerException()));
    expect(find.text('Try again'), findsNothing);

    int retries = 0;
    await pumpInApp(
      tester,
      AppErrorState(error: const ServerException(), onRetry: () => retries++),
    );

    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('picks an icon that matches the failure', (
    WidgetTester tester,
  ) async {
    await pumpInApp(tester, const AppErrorState(error: NetworkException()));
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await pumpInApp(tester, const AppErrorState(error: NotFoundException()));
    expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
  });
}
