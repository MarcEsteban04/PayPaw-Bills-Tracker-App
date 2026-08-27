import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/theme/app_theme.dart';
import 'package:paypaw/features/debts/data/dtos/debt_with_status_dto.dart';
import 'package:paypaw/features/debts/domain/entities/debt_direction.dart';
import 'package:paypaw/features/debts/domain/entities/debt_with_status.dart';
import 'package:paypaw/features/debts/presentation/controllers/debt_providers.dart';
import 'package:paypaw/features/debts/presentation/widgets/debt_summary_card.dart';

/// The utang card on the dashboard.
void main() {
  DebtWithStatus debt({
    required String id,
    DebtDirection direction = DebtDirection.iOwe,
    int principal = 300000,
    Object? dueOn = '2026-09-30',
    Object? settledAt,
  }) => DebtWithStatusDto.toEntity(<String, dynamic>{
    'debt_id': id,
    'user_id': 'user-1',
    'direction': direction.wireValue,
    'counterparty_name': id,
    'counterparty_contact': null,
    'principal_minor': principal,
    'currency': 'PHP',
    'repaid_minor': 0,
    'outstanding_minor': principal,
    'last_paid_at': null,
    'payment_count': 0,
    'is_fully_repaid': false,
    'today': '2026-09-03',
    'incurred_on': '2026-08-12',
    'due_on': dueOn,
    'notes': null,
    'settled_at': settledAt,
    'created_at': '2026-08-12T02:30:00Z',
    'updated_at': '2026-08-12T02:30:00Z',
  });

  Future<void> pumpCard(WidgetTester tester, List<DebtWithStatus> debts) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          debtsProvider.overrideWith(
            (Ref ref) => Future<List<DebtWithStatus>>.value(debts),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: DebtSummaryCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('is absent when there is no open utang', (
    WidgetTester tester,
  ) async {
    // A card reading ₱0.00 teaches somebody to ignore that part of the screen.
    await pumpCard(tester, const <DebtWithStatus>[]);

    expect(find.text('Utang'), findsNothing);
  });

  testWidgets('and when everything open has been settled', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana', settledAt: '2026-09-02T01:00:00Z'),
    ]);

    expect(find.text('Utang'), findsNothing);
  });

  testWidgets('shows only the side that has something on it', (
    WidgetTester tester,
  ) async {
    // "OWED TO YOU ₱0.00 · 0 people" is the ₱0.00 fault one column in — absence
    // taking up half the width, and not reassuring the way "₱0.00 overdue" is.
    await pumpCard(tester, <DebtWithStatus>[debt(id: 'Ana')]);

    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('OWED TO YOU'), findsNothing);
    expect(find.text('₱3,000.00'), findsOneWidget);
  });

  testWidgets('and both when both do', (WidgetTester tester) async {
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana'),
      debt(id: 'Ben', direction: DebtDirection.owedToMe, principal: 100000),
    ]);

    expect(find.text('YOU OWE'), findsOneWidget);
    expect(find.text('OWED TO YOU'), findsOneWidget);
    // Never a third figure. Netting the two would treat a receivable as cash.
    expect(find.textContaining('net', findRichText: true), findsNothing);
  });

  testWidgets('names who is next, and when', (WidgetTester tester) async {
    // The name is the whole reason the line is worth a row of the card. "Next on
    // Sep 12" makes the reader open the screen to find out whose.
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana', dueOn: '2026-09-12'),
      debt(id: 'Ben', dueOn: '2026-10-30'),
    ]);

    expect(find.text('Next: Ana on Sep 12'), findsOneWidget);
  });

  testWidgets('words the next line for the other direction too', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ben', direction: DebtDirection.owedToMe, dueOn: '2026-09-12'),
    ]);

    expect(find.text('Ben owes you back by Sep 12'), findsOneWidget);
  });

  testWidgets('calls out what is late, and says which side', (
    WidgetTester tester,
  ) async {
    // Utang you owe past its date is something to pay. Utang owed to you past
    // its date is somebody to ask. One sentence for both would say neither.
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana', dueOn: '2026-08-20'),
    ]);

    expect(find.text('₱3,000.00 is past the date you agreed'), findsOneWidget);
  });

  testWidgets('and words it the other way round', (WidgetTester tester) async {
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ben', direction: DebtDirection.owedToMe, dueOn: '2026-08-20'),
    ]);

    expect(find.text('₱3,000.00 was due back by now'), findsOneWidget);
  });

  testWidgets('replaces the next line when the soonest is already late', (
    WidgetTester tester,
  ) async {
    // "What is next" for somebody already late is the thing they are late for,
    // and the overdue strip has already said it. Printing both would say it
    // twice.
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana', dueOn: '2026-08-20'),
    ]);

    expect(find.textContaining('Next:'), findsNothing);
  });

  testWidgets('counts the ones with no date, so they do not vanish', (
    WidgetTester tester,
  ) async {
    // They are in the figure above and in neither line below. Saying so is how
    // the card admits it.
    await pumpCard(tester, <DebtWithStatus>[
      debt(id: 'Ana', dueOn: null),
      debt(id: 'Ben', dueOn: null),
    ]);

    expect(find.text('2 with no date agreed'), findsOneWidget);
  });

  testWidgets('and says it in the singular for one', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, <DebtWithStatus>[debt(id: 'Ana', dueOn: null)]);

    expect(find.text('1 with no date agreed'), findsOneWidget);
    expect(find.text('1 person'), findsOneWidget);
  });
}
