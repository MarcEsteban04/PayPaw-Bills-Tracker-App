import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/presentation/widgets/app_dialog.dart';
import 'package:paypaw/core/theme/app_theme.dart';

/// The confirm dialog decides whether something irreversible happens, so its
/// return value is worth pinning down — especially the dismissal case, where
/// getting it wrong means deleting data the user never agreed to delete.
void main() {
  Future<bool?> showAndTap(WidgetTester tester, String? tapLabel) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context: context,
                  title: 'Delete this bill?',
                  message: 'This cannot be undone.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    if (tapLabel == null) {
      // Dismiss by tapping the barrier outside the dialog.
      await tester.tapAt(const Offset(10, 10));
    } else {
      await tester.tap(find.text(tapLabel));
    }
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('resolves true when confirmed', (WidgetTester tester) async {
    expect(await showAndTap(tester, 'Delete'), isTrue);
  });

  testWidgets('resolves false when cancelled', (WidgetTester tester) async {
    expect(await showAndTap(tester, 'Cancel'), isFalse);
  });

  testWidgets('resolves false when dismissed', (WidgetTester tester) async {
    // A dismissal is not consent. If this ever returns true, tapping outside a
    // delete confirmation would delete the bill.
    expect(await showAndTap(tester, null), isFalse);
  });

  testWidgets('shows the title and message', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                title: 'Reminder set',
                message: 'PayPaw will notify you three days before.',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Reminder set'), findsOneWidget);
    expect(
      find.text('PayPaw will notify you three days before.'),
      findsOneWidget,
    );
  });
}
