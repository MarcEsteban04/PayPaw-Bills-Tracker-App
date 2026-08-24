import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/presentation/widgets/app_bottom_sheet.dart';
import 'package:paypaw/core/theme/app_theme.dart';

/// The sheet wrapper.
///
/// Written because of a reported bug: the category picker painted the
/// yellow-and-black overflow stripe across its last row. `isScrollControlled`
/// offers the sheet the whole screen, `mainAxisSize.min` asks the child how tall
/// it wants to be, and a `ListView` — even a shrink-wrapping one — answers with
/// its full content height. Thirteen categories plus a title plus the insets came
/// to more than the room available.
void main() {
  Future<void> openSheet(
    WidgetTester tester, {
    required Widget child,
    String? title,
    Size size = const Size(392, 800),
  }) async {
    tester.view
      ..physicalSize = size * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: title,
                child: child,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// A list longer than any phone.
  Widget longList() => ListView.builder(
    shrinkWrap: true,
    itemCount: 30,
    itemBuilder: (_, int index) => ListTile(title: Text('Row $index')),
  );

  group('a child taller than the screen', () {
    testWidgets('does not overflow', (WidgetTester tester) async {
      await openSheet(tester, title: 'Category', child: longList());

      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls instead', (WidgetTester tester) async {
      await openSheet(tester, title: 'Category', child: longList());

      expect(find.text('Row 0'), findsOneWidget);
      // Off-screen to begin with, reachable by scrolling — which is the
      // behaviour the overflow was standing in for.
      expect(find.text('Row 29'), findsNothing);

      await tester.scrollUntilVisible(find.text('Row 29'), 300);

      expect(find.text('Row 29'), findsOneWidget);
    });

    testWidgets('and still does not overflow on a small phone', (
      WidgetTester tester,
    ) async {
      await openSheet(
        tester,
        title: 'Category',
        child: longList(),
        size: const Size(320, 568),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('a short child', () {
    testWidgets('still hugs its content rather than filling the screen', (
      WidgetTester tester,
    ) async {
      // Flexible is a maximum, not a demand. Without this the fix for the
      // overflow would have turned every small sheet into a full-height one.
      await openSheet(
        tester,
        title: 'Category',
        child: const SizedBox(height: 120, child: Text('short')),
      );

      final double sheetTop = tester.getRect(find.text('Category')).top;

      // Comfortably below the middle of an 800pt screen.
      expect(sheetTop, greaterThan(400));
    });
  });
}
