import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/presentation/widgets/app_text_field.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/controllers/category_providers.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/subscriptions/presentation/widgets/subscription_form.dart';

/// The form both subscription screens share.
///
/// The recurrence editor is not driven here — it has its own tests, and opening
/// a sheet to set a rule would make every case in this file about that sheet.
/// The rule is seeded through [SubscriptionForm.initial] instead, which is also
/// how the edit screen supplies it.
void main() {
  final Recurrence monthly = Recurrence(
    frequency: RecurrenceFrequency.monthly,
    startsOn: DateTime(2026, 9, 18),
    dayOfMonth: 18,
  );

  SubscriptionFormValues? submitted;

  setUp(() => submitted = null);

  Future<void> pumpForm(
    WidgetTester tester, {
    SubscriptionFormValues? initial,
  }) async {
    // Tall enough that the whole form is built. It is a ListView, so a button
    // below the fold does not exist to be tapped.
    tester.view
      ..physicalSize = const Size(392 * 3, 2000 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith(
            (Ref ref) => Future<List<Category>>.value(const <Category>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SubscriptionForm(
              submitLabel: 'Save subscription',
              initial: initial,
              onSubmit: (SubscriptionFormValues values) => submitted = values,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(
      find.widgetWithText(AppTextField, label).first,
      text,
    );
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save subscription'));
    await tester.pumpAndSettle();
  }

  testWidgets('an empty form says what is missing, all of it at once', (
    WidgetTester tester,
  ) async {
    await pumpForm(tester);
    await save(tester);

    expect(submitted, isNull);
    expect(find.text('Say who charges for this'), findsOneWidget);
    expect(find.text('Enter the amount'), findsOneWidget);
    // The one a bill does not have. A subscription that does not repeat is a
    // purchase, so the form refuses rather than storing a template that charges
    // once and stops.
    expect(find.text('Choose how often it charges'), findsOneWidget);
  });

  testWidgets('the service becomes the name when nothing else is given', (
    WidgetTester tester,
  ) async {
    await pumpForm(
      tester,
      initial: SubscriptionFormValues(
        provider: '',
        amount: '',
        recurrence: monthly,
      ),
    );

    await type(tester, 'Service', '  Netflix  ');
    await type(tester, 'Amount per charge', '549');
    await save(tester);

    expect(submitted, isNotNull);
    expect(submitted!.provider, 'Netflix');
    expect(submitted!.effectiveName, 'Netflix');
    expect(submitted!.money, const Money.php(54900));
    // Blank optional fields are absent, not empty strings that would later
    // format as a stray separator after the provider's name.
    expect(submitted!.plan, isNull);
    expect(submitted!.cancellationUrl, isNull);
    expect(submitted!.trialEndsOn, isNull);
    expect(submitted!.autoRenews, isTrue);
  });

  testWidgets('a typed label wins over the service name', (
    WidgetTester tester,
  ) async {
    await pumpForm(
      tester,
      initial: SubscriptionFormValues(
        provider: 'Netflix',
        amount: '549',
        recurrence: monthly,
      ),
    );

    await type(tester, 'Call it something else', 'Netflix — mum');
    await save(tester);

    expect(submitted!.effectiveName, 'Netflix — mum');
  });

  testWidgets('the cancellation link is stored with a scheme', (
    WidgetTester tester,
  ) async {
    await pumpForm(
      tester,
      initial: SubscriptionFormValues(
        provider: 'Netflix',
        amount: '549',
        recurrence: monthly,
      ),
    );

    await type(tester, 'Where to cancel', 'netflix.com/cancelplan');
    await save(tester);

    // Not what was typed. A stored `netflix.com` opens as a relative path.
    expect(submitted!.cancellationUrl, 'https://netflix.com/cancelplan');
  });

  testWidgets('a link that is not one blocks the save', (
    WidgetTester tester,
  ) async {
    await pumpForm(
      tester,
      initial: SubscriptionFormValues(
        provider: 'Netflix',
        amount: '549',
        recurrence: monthly,
      ),
    );

    await type(tester, 'Where to cancel', 'somewhere in my email');
    await save(tester);

    expect(submitted, isNull);
    expect(
      find.text('Enter a web address like netflix.com/cancelplan'),
      findsOneWidget,
    );
  });

  testWidgets('turning off auto-renew is carried through', (
    WidgetTester tester,
  ) async {
    await pumpForm(
      tester,
      initial: SubscriptionFormValues(
        provider: 'Netflix',
        amount: '549',
        recurrence: monthly,
      ),
    );

    await tester.tap(find.text('Renews automatically'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(submitted!.autoRenews, isFalse);
  });
}
