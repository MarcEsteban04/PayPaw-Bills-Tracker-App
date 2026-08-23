import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/presentation/widgets/app_amount_field.dart';

import '../../../helpers/pump_app.dart';

/// The amount field's input filter is the one piece of real logic in the input
/// components, and the one most likely to be broken by a well-meaning edit.
void main() {
  Future<TextEditingController> pumpField(WidgetTester tester) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpInApp(tester, AppAmountField(controller: controller));
    return controller;
  }

  testWidgets('accepts digits and a single decimal point', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), '1250.75');

    expect(controller.text, '1250.75');
  });

  testWidgets('rejects letters and symbols', (WidgetTester tester) async {
    final TextEditingController controller = await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), r'12a5$0');

    expect(controller.text, '1250');
  });

  testWidgets('rejects a second decimal point', (WidgetTester tester) async {
    final TextEditingController controller = await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.enterText(find.byType(TextFormField), '12.5.7');

    // The whole edit is refused rather than partly applied, so the field never
    // holds a value that cannot be parsed.
    expect(controller.text, '12.5');
  });

  testWidgets('rejects more than two decimal places', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = await pumpField(tester);

    await tester.enterText(find.byType(TextFormField), '12.50');
    await tester.enterText(find.byType(TextFormField), '12.509');

    expect(controller.text, '12.50');
  });

  testWidgets('shows the peso sign before anything is typed', (
    WidgetTester tester,
  ) async {
    await pumpField(tester);

    // prefixText would only appear on focus, which is why this is an icon.
    expect(find.text('₱'), findsOneWidget);
  });
}
