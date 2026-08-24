import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/presentation/widgets/recurrence_field.dart';

/// The recurrence field and its editor.
///
/// The arithmetic has its own tests. These are about the control: that the
/// frequency decides which fields appear, that the preview says what the rule
/// actually does, and that dismissing is not the same as clearing.
void main() {
  final DateTime today = DateTime(2026, 8, 25);

  late Recurrence? current;

  Future<void> pumpField(WidgetTester tester, {Recurrence? initial}) async {
    current = initial;

    tester.view
      ..physicalSize = const Size(392 * 3, 1400 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Scaffold(
            body: RecurrenceField(
              value: current,
              today: today,
              onChanged: (Recurrence? value) => setState(() => current = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byType(RecurrenceField));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('the field', () {
    testWidgets('says so when nothing repeats', (WidgetTester tester) async {
      // Null is the common value — most bills do not repeat — so the empty state
      // answers the question rather than being blank.
      await pumpField(tester);

      expect(find.text('Does not repeat'), findsOneWidget);
    });

    testWidgets('shows the rule in words when there is one', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        initial: Recurrence(
          frequency: RecurrenceFrequency.weekly,
          weekday: DateTime.friday,
          intervalCount: 2,
          startsOn: today,
        ),
      );

      expect(find.text('Every 2 weeks on Friday'), findsOneWidget);
    });
  });

  group('the editor', () {
    testWidgets('defaults to monthly on the start date day', (
      WidgetTester tester,
    ) async {
      // A new rule should already describe the day the user is on, rather than an
      // arbitrary one they have to notice and correct. 25 August.
      await pumpField(tester);
      await openEditor(tester);

      expect(find.text('Every month on the 25th'), findsOneWidget);
    });

    testWidgets('builds a rule from a unit and a count', (
      WidgetTester tester,
    ) async {
      // Rather than a list of named presets. The stepper plus the unit covers
      // every combination the model allows, including the ones nobody thought to
      // put on a list.
      await pumpField(tester);
      await openEditor(tester);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More often'));
      await tester.pumpAndSettle();

      // Bi-weekly, without a wire value of its own.
      expect(find.textContaining('Every 2 weeks'), findsOneWidget);

      await save(tester);

      expect(current?.frequency, RecurrenceFrequency.weekly);
      expect(current?.intervalCount, 2);
    });

    testWidgets('the interval unit is singular at 1 and plural above it', (
      WidgetTester tester,
    ) async {
      await pumpField(tester);
      await openEditor(tester);

      expect(find.text('month'), findsOneWidget);

      await tester.tap(find.byTooltip('More often'));
      await tester.pumpAndSettle();

      expect(find.text('months'), findsOneWidget);
    });

    testWidgets('will not step below 1', (WidgetTester tester) async {
      // The column allows 1 to 60, and "every 0 months" is not a schedule.
      await pumpField(tester);
      await openEditor(tester);

      // By icon, not by tooltip: `byTooltip` finds the Tooltip wrapping the
      // button, so casting its widget to IconButton is a type error.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.remove_rounded),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('offers only the fields its frequency uses', (
      WidgetTester tester,
    ) async {
      // A weekly rule showing a day-of-month picker would be offering a field
      // that changes nothing — the same thing the database's shape constraint
      // says about which fields each frequency needs.
      await pumpField(tester);
      await openEditor(tester);

      expect(find.text('Day of the month'), findsOneWidget);
      expect(find.text('Month'), findsNothing);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();

      expect(find.text('Day of the month'), findsNothing);
      expect(find.text('ON'), findsOneWidget);

      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();

      expect(find.text('Day of the month'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });
  });

  group('the preview', () {
    testWidgets('shows the next three dates', (WidgetTester tester) async {
      await pumpField(tester);
      await openEditor(tester);

      expect(find.textContaining('Next: Aug 25'), findsOneWidget);
    });

    testWidgets('is where month-end clamping becomes visible', (
      WidgetTester tester,
    ) async {
      // The reason the preview exists. "Every month on the 31st" does not tell
      // anyone what February does, and without this the answer only appears when
      // a bill is generated months later.
      await pumpField(
        tester,
        initial: Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 31,
          startsOn: DateTime(2026, 12, 2),
        ),
      );
      await openEditor(tester);

      // December, then February's clamp — January 31 is in between.
      expect(find.textContaining('Dec 31'), findsOneWidget);
      expect(find.textContaining('Feb 28'), findsOneWidget);
    });

    testWidgets('updates as the rule changes', (WidgetTester tester) async {
      await pumpField(tester);
      await openEditor(tester);

      expect(find.textContaining('Every month'), findsOneWidget);

      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();

      // 'Quarterly' is also the chip's own label, so the description is what is
      // asserted rather than the word on its own.
      expect(find.textContaining('Every quarter on the'), findsOneWidget);
    });
  });

  group('closing it', () {
    testWidgets('Save returns the rule', (WidgetTester tester) async {
      await pumpField(tester);
      await openEditor(tester);
      await tester.tap(find.text('Quarterly'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(current?.frequency, RecurrenceFrequency.quarterly);
      expect(find.textContaining('Every quarter'), findsOneWidget);
    });

    testWidgets('"Does not repeat" clears an existing rule', (
      WidgetTester tester,
    ) async {
      await pumpField(
        tester,
        initial: Recurrence(
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 15,
          startsOn: today,
        ),
      );
      await openEditor(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Does not repeat'));
      await tester.pumpAndSettle();

      expect(current, isNull);
      expect(find.text('Does not repeat'), findsOneWidget);
    });

    testWidgets('dismissing leaves an existing rule alone', (
      WidgetTester tester,
    ) async {
      // Not the same answer as clearing, which is why the editor returns a sealed
      // result rather than a nullable Recurrence.
      final Recurrence original = Recurrence(
        frequency: RecurrenceFrequency.monthly,
        dayOfMonth: 15,
        startsOn: today,
      );
      await pumpField(tester, initial: original);
      await openEditor(tester);

      // Change something, then dismiss without saving.
      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Save'))).pop();
      await tester.pumpAndSettle();

      expect(current, original);
    });
  });
}
