import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/app/paypaw_app.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Boot test for the architecture wiring.
///
/// It asserts almost nothing about the UI on purpose. Its job is to fail the
/// moment the pieces stop fitting together — a provider that is read before it
/// is overridden, a router with no matching initial route, a theme that throws
/// while building — which is exactly the class of breakage that is otherwise
/// only found by launching the app.
void main() {
  testWidgets('app boots and renders its initial route', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const PayPawApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PayPaw'), findsOneWidget);
  });
}
