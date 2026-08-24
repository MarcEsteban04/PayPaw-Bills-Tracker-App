import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/config/app_config.dart';
import 'package:paypaw/core/presentation/widgets/unconfigured_backend_banner.dart';
import 'package:paypaw/core/providers/supabase_providers.dart';
import 'package:paypaw/core/theme/app_theme.dart';

/// The warning that exists because the failure it explains is invisible.
///
/// Without credentials the route guard deliberately does nothing, so the app
/// opens on the dashboard with no route to sign-in and nothing on screen saying
/// why. That cost two rounds of "why is the dashboard showing".
void main() {
  Future<void> pump(WidgetTester tester, {required bool configured}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isBackendConfiguredProvider.overrideWithValue(configured)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: UnconfiguredBackendBanner.wrap(
            const Scaffold(body: Center(child: Text('app content'))),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('when the backend is not configured', () {
    testWidgets('it says so, and says what to do about it', (
      WidgetTester tester,
    ) async {
      await pump(tester, configured: false);

      expect(find.textContaining('No Supabase config'), findsOneWidget);
      // The exact thing to copy. A warning that only says something is wrong
      // sends you back to the docs; this one ends the problem.
      expect(
        find.textContaining('--dart-define-from-file=config/dev.json'),
        findsOneWidget,
      );
    });

    testWidgets('the app is still fully usable underneath', (
      WidgetTester tester,
    ) async {
      // The no-backend mode exists so UI work does not need credentials. The
      // warning must not get in the way of that.
      await pump(tester, configured: false);

      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('it takes space rather than covering the app', (
      WidgetTester tester,
    ) async {
      // An overlay would float over an app bar and hide a title, and a debug
      // affordance that obscures what you are looking at gets suppressed.
      await pump(tester, configured: false);

      final double stripBottom = tester
          .getRect(find.textContaining('No Supabase config'))
          .bottom;
      final double contentTop = tester.getRect(find.text('app content')).top;

      expect(contentTop, greaterThan(stripBottom));
    });
  });

  group('when the backend is configured', () {
    testWidgets('nothing is shown and nothing is shifted', (
      WidgetTester tester,
    ) async {
      await pump(tester, configured: true);

      expect(find.textContaining('No Supabase config'), findsNothing);
      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('the child is returned untouched', (WidgetTester tester) async {
      // No Column, no second MediaQuery — the tree is identical to one without
      // this widget, so it cannot affect a configured build's layout.
      await pump(tester, configured: true);

      expect(
        find.descendant(
          of: find.byType(UnconfiguredBackendBanner),
          matching: find.byType(Column),
        ),
        findsNothing,
      );
    });
  });

  group('the config file contract', () {
    // The other half of this problem: the flag can be passed correctly and still
    // do nothing if the key names in the file and in AppConfig disagree. Nothing
    // else would catch that — the app would simply look unconfigured.
    test('the example file names exactly the keys AppConfig reads', () {
      final File example = File('config/dev.example.json');
      expect(
        example.existsSync(),
        isTrue,
        reason: '${example.path} is missing',
      );

      final Map<String, dynamic> keys =
          jsonDecode(example.readAsStringSync()) as Map<String, dynamic>;

      // A build with no defines reports both as missing, which is exactly the
      // list of names the file has to supply.
      expect(
        keys.keys.toSet(),
        AppConfig.missingKeys.toSet(),
        reason:
            'config/dev.example.json and AppConfig disagree about the define '
            'names, so a correctly-passed config file would still read as empty',
      );
    });

    test('the VS Code workspace passes the config to every run', () {
      // Belt and braces for the actual mistake that happened twice: the flag
      // living only in one launch configuration, so the Run button, the codelens
      // above main() and a bare `flutter run` all started unconfigured.
      final File settings = File('.vscode/settings.json');
      expect(
        settings.existsSync(),
        isTrue,
        reason: '.vscode/settings.json is missing',
      );

      expect(
        settings.readAsStringSync(),
        contains('--dart-define-from-file=config/dev.json'),
      );
    });
  });
}
