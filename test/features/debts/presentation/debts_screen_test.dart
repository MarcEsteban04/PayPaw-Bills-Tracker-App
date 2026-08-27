import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/debts/data/dtos/debt_with_status_dto.dart';
import 'package:paypaw/features/debts/domain/entities/debt_direction.dart';
import 'package:paypaw/features/debts/domain/entities/debt_with_status.dart';
import 'package:paypaw/features/debts/presentation/controllers/debt_providers.dart';
import 'package:paypaw/features/debts/presentation/screens/debts_screen.dart';
import 'package:paypaw/features/debts/presentation/widgets/debt_tile.dart';

/// The utang list, in both directions.
///
/// Sprint 53 shipped four debt screens with domain tests and no widget tests.
/// These are the ones that matter: the direction switch is the whole reason one
/// screen serves both halves of the ledger, and nothing was checking that it
/// actually filters.
void main() {
  DebtWithStatus debt({
    required String id,
    required String name,
    DebtDirection direction = DebtDirection.iOwe,
    int principal = 500000,
    int repaid = 0,
    int payments = 0,
    bool fullyRepaid = false,
    Object? dueOn = '2026-09-30',
    Object? settledAt,
  }) => DebtWithStatusDto.toEntity(<String, dynamic>{
    'debt_id': id,
    'user_id': 'user-1',
    'direction': direction.wireValue,
    'counterparty_name': name,
    'counterparty_contact': null,
    'principal_minor': principal,
    'currency': 'PHP',
    'repaid_minor': repaid,
    'outstanding_minor': (principal - repaid).clamp(0, principal),
    'last_paid_at': null,
    'payment_count': payments,
    'is_fully_repaid': fullyRepaid,
    'today': '2026-09-03',
    'incurred_on': '2026-08-12',
    'due_on': dueOn,
    'notes': null,
    'settled_at': settledAt,
    'created_at': '2026-08-12T02:30:00Z',
    'updated_at': '2026-08-12T02:30:00Z',
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    List<DebtWithStatus> debts, {
    DebtDirection initial = DebtDirection.iOwe,
  }) async {
    tester.view
      ..physicalSize = const Size(392 * 3, 1200 * 3)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtsProvider.overrideWith(
            (Ref ref) => Future<List<DebtWithStatus>>.value(debts),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: DebtsScreen(initialDirection: initial),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> namesOnScreen(WidgetTester tester) => tester
      .widgetList<DebtTile>(find.byType(DebtTile))
      .map((DebtTile tile) => tile.item.counterpartyName)
      .toList();

  group('the direction switch', () {
    testWidgets('shows only the side that is selected', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(id: 'b', name: 'Kuya Ben', direction: DebtDirection.owedToMe),
      ]);

      expect(namesOnScreen(tester), <String>['Tita Ana']);
    });

    testWidgets('and switches to the other one', (WidgetTester tester) async {
      // The whole reason one screen serves both halves of the ledger. Nothing
      // was checking that the switch actually filters.
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(id: 'b', name: 'Kuya Ben', direction: DebtDirection.owedToMe),
      ]);

      await tester.tap(find.text('Owed to me'));
      await tester.pumpAndSettle();

      expect(namesOnScreen(tester), <String>['Kuya Ben']);
    });

    testWidgets('opens on whichever side it was sent to', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(id: 'b', name: 'Kuya Ben', direction: DebtDirection.owedToMe),
      ], initial: DebtDirection.owedToMe);

      expect(namesOnScreen(tester), <String>['Kuya Ben']);
    });

    testWidgets('counts the other side, so it says whether to press it', (
      WidgetTester tester,
    ) async {
      // Counted across everything rather than the filtered list. A tab that does
      // not say whether it has anything in it is a tab people stop pressing.
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(id: 'b', name: 'Kuya Ben', direction: DebtDirection.owedToMe),
        debt(id: 'c', name: 'Ate Cel', direction: DebtDirection.owedToMe),
      ]);

      // "I owe 1" and "Owed to me 2", both visible without switching.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('does not count settled ones in the badge', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(id: 'b', name: 'Old one', settledAt: '2026-09-02T01:00:00Z'),
      ]);

      // One open, not two. A closed debt is not something to act on.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });
  });

  group('the total', () {
    testWidgets('is worded for the direction showing', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
      ]);

      expect(find.text('YOU STILL OWE'), findsOneWidget);

      await tester.tap(find.text('Owed to me'));
      await tester.pumpAndSettle();
      // No rows on that side, so the empty state shows instead of a total.
      expect(find.text('Nobody owes you'), findsOneWidget);
    });

    testWidgets('adds up what is left, not what was borrowed', (
      WidgetTester tester,
    ) async {
      // ₱5,000 with ₱2,000 repaid, plus ₱1,500 untouched. The answer is ₱4,500 —
      // ₱6,500 would be the figure nobody owes any more.
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana', repaid: 200000, payments: 1),
        debt(id: 'b', name: 'Kuya Ben', principal: 150000),
      ]);

      expect(find.text('₱4,500.00'), findsOneWidget);
    });

    testWidgets('leaves settled debts out of it', (WidgetTester tester) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana'),
        debt(
          id: 'b',
          name: 'Old one',
          principal: 999900,
          settledAt: '2026-09-02T01:00:00Z',
        ),
      ]);

      expect(find.text('₱5,000.00'), findsWidgets);
      expect(find.text('1 open · 1 settled'), findsOneWidget);
    });
  });

  group('a row', () {
    testWidgets('leads with what is left and says how many payments', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana', repaid: 200000, payments: 2),
      ]);

      // Scoped to the row: the total card above shows the same figure when there
      // is only one debt.
      expect(
        find.descendant(
          of: find.byType(DebtTile),
          matching: find.text('₱3,000.00'),
        ),
        findsOneWidget,
      );
      expect(find.text('of ₱5,000.00'), findsOneWidget);
      expect(find.text('2 payments · Due Sep 30'), findsOneWidget);
    });

    testWidgets('says when nobody agreed a date', (WidgetTester tester) async {
      // The case that separates utang from a bill, and it is a fact worth
      // printing rather than a blank.
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana', dueOn: null),
      ]);

      // The whole caption, not a fragment of it. An untouched debt says only
      // when it is due — see the note on _caption: leading with "Nothing repaid
      // yet" pushed the date off the end of a real phone.
      expect(find.text('No date agreed'), findsOneWidget);
      expect(find.text('OVERDUE'), findsNothing);
    });

    testWidgets('calls out one that is late', (WidgetTester tester) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana', dueOn: '2026-08-20'),
      ]);

      expect(find.text('OVERDUE'), findsOneWidget);
      expect(find.textContaining('Was due'), findsOneWidget);
    });

    testWidgets('calls out one the numbers say is square', (
      WidgetTester tester,
    ) async {
      // The one row whose obvious next action is a tap rather than a payment:
      // the arithmetic is done and the user has not closed it.
      await pumpScreen(tester, <DebtWithStatus>[
        debt(
          id: 'a',
          name: 'Tita Ana',
          repaid: 500000,
          payments: 3,
          fullyRepaid: true,
        ),
      ]);

      expect(find.text('FULLY REPAID'), findsOneWidget);
    });

    testWidgets('and one the user has closed', (WidgetTester tester) async {
      await pumpScreen(tester, <DebtWithStatus>[
        debt(id: 'a', name: 'Tita Ana', settledAt: '2026-09-02T01:00:00Z'),
      ]);

      expect(find.text('SETTLED'), findsOneWidget);
    });
  });

  group('with nothing on it', () {
    testWidgets('says so in the direction\'s own words', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const <DebtWithStatus>[]);

      expect(find.text('You owe nobody'), findsOneWidget);

      await tester.tap(find.text('Owed to me'));
      await tester.pumpAndSettle();

      expect(find.text('Nobody owes you'), findsOneWidget);
    });
  });
}
