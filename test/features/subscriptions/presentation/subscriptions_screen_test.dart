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
import 'package:paypaw/features/subscriptions/presentation/widgets/subscription_share_bar.dart';
import 'package:paypaw/features/subscriptions/presentation/widgets/subscription_spend_card.dart';
import 'package:paypaw/features/subscriptions/presentation/widgets/subscription_tile.dart';

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
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  }) => Subscription(
    template: RecurringBill(
      id: id,
      userId: 'user-1',
      kind: RecurringBillKind.subscription,
      name: name ?? provider,
      payee: provider,
      amount: Money.php(amountMinor),
      recurrence: Recurrence(
        frequency: frequency,
        startsOn: DateTime(2026, 1, 18),
        dayOfMonth: 18,
        monthOfYear: frequency == RecurrenceFrequency.yearly ? 1 : null,
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
    // Scoped to the row. With one subscription on screen the card above totals
    // the same figure, so a bare finder legitimately matches twice.
    expect(
      find.descendant(
        of: find.byType(SubscriptionTile),
        matching: find.text('₱549.00'),
      ),
      findsOneWidget,
    );
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

  group('what it all costs', () {
    testWidgets('leads with the monthly figure and the year beside it', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <Subscription>[
        subscription(),
        subscription(id: 'sub-2', provider: 'Spotify', amountMinor: 19900),
      ]);

      expect(find.text('EVERY MONTH'), findsOneWidget);
      expect(find.text('₱748.00'), findsOneWidget);
      // The year is the number that changes minds, so it sits beside the
      // headline rather than buried in a sentence under it. The count says what
      // the figures are *of*.
      expect(find.text('A YEAR'), findsOneWidget);
      expect(find.text('₱8,976.00'), findsOneWidget);
      expect(find.text('2 services'), findsOneWidget);
    });

    testWidgets('names the dearest by its monthly equivalent', (
      WidgetTester tester,
    ) async {
      // ₱1,200 a year is ₱100 a month, so Spotify at ₱149 is the dearer of the
      // two — and the row's own figures say the opposite. This is the case the
      // ranking exists for.
      await pumpScreen(tester, <Subscription>[
        subscription(
          provider: 'Domain',
          amountMinor: 120000,
          frequency: RecurrenceFrequency.yearly,
        ),
        subscription(id: 'sub-2', provider: 'Spotify', amountMinor: 14900),
      ]);

      // ₱149 of a ₱249 monthly total. Stated as a share rather than as a name,
      // because "dearest" alone left the reader to divide — and drawn as one
      // too, by the bar above it.
      expect(find.text('Spotify is 60% of it'), findsOneWidget);
    });

    testWidgets('spells out the monthly equivalent on a non-monthly row', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <Subscription>[
        subscription(
          provider: 'Domain',
          amountMinor: 120000,
          frequency: RecurrenceFrequency.yearly,
        ),
      ]);

      // Scoped to the row: a lone yearly subscription makes the card's annual
      // figure the same number.
      expect(
        find.descendant(
          of: find.byType(SubscriptionTile),
          matching: find.text('₱1,200.00'),
        ),
        findsOneWidget,
      );
      expect(find.text('₱100.00/mo'), findsOneWidget);
    });

    testWidgets('and does not repeat itself on a monthly one', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <Subscription>[subscription()]);

      // The same number twice, one of them with a suffix, is noise.
      expect(find.text('₱549.00/mo'), findsNothing);
    });

    testWidgets('says what a trial will add rather than counting it', (
      WidgetTester tester,
    ) async {
      final DateTime today = DateTime.now();

      await pumpScreen(tester, <Subscription>[
        subscription(),
        subscription(
          id: 'sub-2',
          provider: 'Apple TV+',
          amountMinor: 24900,
          trialEndsOn: DateTime(today.year, today.month, today.day + 5),
        ),
      ]);

      // The committed figure is Netflix alone — the trial adds nothing to it
      // yet. Scoped to the card, because the Netflix row shows the same number.
      expect(
        find.descendant(
          of: find.byType(SubscriptionSpendCard),
          matching: find.text('₱549.00'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('+₱249.00 a month when this trial ends'),
        findsOneWidget,
      );
    });

    testWidgets('draws the split, and the bar has actual height', (
      WidgetTester tester,
    ) async {
      // The height is the assertion. `ColoredBox` with no child has no
      // intrinsic height, so the first version of this bar centred three
      // zero-height segments and rendered as a gap — invisible to every test
      // that only asked whether the widget was in the tree.
      await pumpScreen(tester, <Subscription>[
        subscription(),
        subscription(id: 'sub-2', provider: 'Spotify', amountMinor: 19900),
      ]);

      expect(find.byType(SubscriptionShareBar), findsOneWidget);
      expect(
        tester.getSize(find.byType(SubscriptionShareBar)).height,
        greaterThan(0),
      );
    });

    testWidgets('and draws no split for a single subscription', (
      WidgetTester tester,
    ) async {
      // A bar of one colour says less than the figure above it already did.
      await pumpScreen(tester, <Subscription>[subscription()]);

      expect(find.byType(SubscriptionShareBar), findsNothing);
    });

    testWidgets('has nothing to say when everything is stopped', (
      WidgetTester tester,
    ) async {
      // A card reading "₱0.00 a month · 0 subscriptions" says nothing the list
      // below does not say more clearly.
      await pumpScreen(tester, <Subscription>[subscription(isActive: false)]);

      expect(find.text('EVERY MONTH'), findsNothing);
      expect(find.text('Netflix'), findsOneWidget);
    });
  });

  group('the order', () {
    testWidgets('is soonest-first, and offers cost instead', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <Subscription>[
        subscription(
          provider: 'Domain',
          amountMinor: 120000,
          frequency: RecurrenceFrequency.yearly,
        ),
        subscription(id: 'sub-2', provider: 'Spotify', amountMinor: 14900),
      ]);

      await tester.tap(find.byTooltip('Sort: Next charge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cost'));
      await tester.pumpAndSettle();

      // Dearest per month first, which puts Spotify above the yearly plan whose
      // own figure is eight times larger.
      final List<String> providers = tester
          .widgetList<SubscriptionTile>(find.byType(SubscriptionTile))
          .map((SubscriptionTile tile) => tile.subscription.details.provider)
          .toList();

      expect(providers, <String>['Spotify', 'Domain']);
    });

    testWidgets('offers no control when there is only one row to order', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <Subscription>[subscription()]);

      expect(find.byTooltip('Sort: Next charge'), findsNothing);
    });
  });
}
