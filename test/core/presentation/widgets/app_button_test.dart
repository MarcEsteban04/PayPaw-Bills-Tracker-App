import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/presentation/widgets/app_button.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('AppPrimaryButton', () {
    testWidgets('calls onPressed when tapped', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(
        tester,
        AppPrimaryButton(label: 'Save', onPressed: () => taps++),
      );

      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('shows a spinner and blocks taps while busy', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpInApp(
        tester,
        AppPrimaryButton(label: 'Save', isBusy: true, onPressed: () => taps++),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byType(AppPrimaryButton));
      await tester.pump();

      // This is the point of the busy state: a slow save cannot be submitted
      // twice by an impatient second tap.
      expect(taps, 0);
    });

    testWidgets('drops the glow when disabled', (WidgetTester tester) async {
      await pumpInApp(
        tester,
        const AppPrimaryButton(label: 'Save', onPressed: null),
      );

      final DecoratedBox decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(AppPrimaryButton),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final BoxDecoration decoration = decorated.decoration as BoxDecoration;

      expect(decoration.boxShadow, isNull);
    });
  });

  group('AppDangerButton', () {
    testWidgets('renders its label and fires', (WidgetTester tester) async {
      int taps = 0;
      await pumpInApp(
        tester,
        AppDangerButton(label: 'Delete', onPressed: () => taps++),
      );

      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.byType(AppDangerButton));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
