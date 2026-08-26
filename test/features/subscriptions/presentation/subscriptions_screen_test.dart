import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/presentation/controllers/bill_detail_provider.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';
import 'package:paypaw/features/subscriptions/presentation/controllers/subscription_providers.dart';
import 'package:paypaw/features/subscriptions/presentation/screens/subscriptions_screen.dart';

/// What the subscriptions list says, and about which subscriptions.
///
/// The two decisions worth pinning down are that **stopped subscriptions stay on
/// the list** — a cancelled one is the record of a decision, and hiding it would
/// leave somebody wondering whether it ever existed — and that a row carries **at
/// most one badge**, in the order the states matter.
void main() {
  Subscription subscription({
    String id = 'sub-1',
    String provider = 'Netflix',
    String? name,
    String? planName,
    DateTime? trialEndsOn,
    bool autoRenews = true,
    bool isActive = true,
    int amountMinor = 54900,
  }) => Subscription(
    template: RecurringBill(
      id: id,
      userId: 'user-1',
      kind: RecurringBillKind.subscription,
      name: name ?? provider,
      payee: provider,
      amount: Money.php(amountMinor),
      recurrence: Recurrence(
        frequency: RecurrenceFrequency.monthly,
        startsOn: DateTime(2026, 1, 18),
        dayOfMonth: 18,
      ),
      nextDueOn: DateTime(2026, 9, 18),
      isActive: isActive,
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    ),
    details: SubscriptionDetails(
      recurringBillId: id,
      provider: provider,
      planName: planName,
      trialEndsOn: trialEndsOn,
      autoRenews: autoRenews,
    ),
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    List<Subscription> subscriptions,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionsProvider.overrideWith(
            (Ref ref) => Future<List<Subscription>>.value(subscriptions),
          ),
          // The list takes today from the database rather than the device clock,
          // so a trial countdown cannot disagree with the dates beside it. With
          // no bills loaded it falls back to `DateTime.now()`, which is why the
          // trial cases below are dated relative to it.
          billsProvider.overrideWith(
            (Ref ref) =>
                Future<List<BillWithStatus>>.value(const <BillWithStatus>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const SubscriptionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('says what the screen is for when there is nothing on it', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, const <Subscription>[]);

    expect(find.text('No subscriptions yet'), findsOneWidget);
    expect(find.text('Add a subscription'), findsWidgets);
  });

  testWidgets('leads with the service, and the plan beside it', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, <Subscription>[subscription(planName: 'Premium')]);

    expect(find.text('Netflix · Premium'), findsOneWidget);
    expect(find.text('₱549.00'), findsOneWidget);
  });

  testWidgets('a stopped subscription stays, and says so', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, <Subscription>[
      subscription(provider: 'Spotify', isActive: false),
    ]);

    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('STOPPED'), findsOneWidget);
    // Not a date. A stopped subscription has no next charge, and printing one
    // would read as money still going out.
    expect(find.text('Stopped'), findsOneWidget);
  });

  testWidgets('a subscription set not to renew is called out', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, <Subscription>[
      subscription(provider: 'Disney+', autoRenews: false),
    ]);

    expect(find.text('WILL NOT RENEW'), findsOneWidget);
  });

  testWidgets('a running trial outranks every other badge', (
    WidgetTester tester,
  ) async {
    final DateTime today = DateTime.now();

    await pumpScreen(tester, <Subscription>[
      subscription(
        provider: 'Apple TV+',
        autoRenews: false,
        trialEndsOn: DateTime(today.year, today.month, today.day + 3),
      ),
    ]);

    // A trial converts whether or not anybody notices; "will not renew" is a
    // decision already taken. Only one chip is shown, and it is this one.
    expect(find.text('TRIAL · 3 DAYS'), findsOneWidget);
    expect(find.text('WILL NOT RENEW'), findsNothing);
  });

  testWidgets('the last day of a trial says today, not zero days', (
    WidgetTester tester,
  ) async {
    final DateTime today = DateTime.now();

    await pumpScreen(tester, <Subscription>[
      subscription(
        provider: 'Apple TV+',
        trialEndsOn: DateTime(today.year, today.month, today.day),
      ),
    ]);

    expect(find.text('TRIAL ENDS TODAY'), findsOneWidget);
  });
}
