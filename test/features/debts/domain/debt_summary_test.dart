import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/debts/data/dtos/debt_with_status_dto.dart';
import 'package:paypaw/features/debts/domain/entities/debt_direction.dart';
import 'package:paypaw/features/debts/domain/entities/debt_summary.dart';
import 'package:paypaw/features/debts/domain/entities/debt_with_status.dart';

/// Where somebody stands on utang, both directions at once.
void main() {
  DebtWithStatus debt({
    required String id,
    DebtDirection direction = DebtDirection.iOwe,
    int principal = 300000,
    int repaid = 0,
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
    'repaid_minor': repaid,
    'outstanding_minor': (principal - repaid).clamp(0, principal),
    'last_paid_at': null,
    'payment_count': repaid > 0 ? 1 : 0,
    'is_fully_repaid': repaid >= principal,
    'today': '2026-09-03',
    'incurred_on': '2026-08-12',
    'due_on': dueOn,
    'notes': null,
    'settled_at': settledAt,
    'created_at': '2026-08-12T02:30:00Z',
    'updated_at': '2026-08-12T02:30:00Z',
  });

  group('the two sides', () {
    test('are counted separately and never netted', () {
      // The whole design decision. "You are ₱3,000 down overall" is one tidy
      // number and it treats a receivable as cash — money lent informally comes
      // back late, in kind, or not at all. Both figures stand, and there is no
      // getter that subtracts them.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', principal: 500000),
        debt(id: 'b', principal: 200000, direction: DebtDirection.owedToMe),
      ]);

      expect(summary.owed, const Money.php(500000));
      expect(summary.receivable, const Money.php(200000));
      expect(summary.owedCount, 1);
      expect(summary.receivableCount, 1);
    });

    test('add up what is left, not what changed hands', () {
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', principal: 500000, repaid: 200000),
      ]);

      expect(summary.owed, const Money.php(300000));
    });

    test('leave settled debts out entirely', () {
      // History, not money that is still moving — the same rule the monthly
      // subscription commitment applies to a paused plan.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', principal: 500000),
        debt(id: 'b', principal: 999900, settledAt: '2026-09-02T01:00:00Z'),
      ]);

      expect(summary.owed, const Money.php(500000));
      expect(summary.openCount, 1);
    });
  });

  group('overdue', () {
    test('is split by direction, because the action differs', () {
      // Utang you owe past its date is something to go and pay. Utang owed to
      // you past its date is somebody to go and ask.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', principal: 500000, dueOn: '2026-08-20'),
        debt(
          id: 'b',
          principal: 200000,
          direction: DebtDirection.owedToMe,
          dueOn: '2026-08-25',
        ),
      ]);

      expect(summary.overdueOwed, const Money.php(500000));
      expect(summary.overdueReceivable, const Money.php(200000));
      expect(summary.overdueCount, 2);
    });

    test('ignores a debt nobody agreed a date for', () {
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', dueOn: null),
      ]);

      expect(summary.hasOverdue, isFalse);
    });

    test('and a settled one, however late it was', () {
      expect(
        DebtSummary.of(<DebtWithStatus>[
          debt(id: 'a', dueOn: '2026-01-20', settledAt: '2026-02-20T01:00:00Z'),
        ]).hasOverdue,
        isFalse,
      );
    });
  });

  group('undated debts', () {
    test('are counted, because otherwise they vanish from the card', () {
      // A card built from "overdue" and "upcoming" would show this debt in its
      // figures and in neither line. Counting it is how the card admits that.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', dueOn: null),
        debt(id: 'b', dueOn: null),
        debt(id: 'c'), // the default date
      ]);

      expect(summary.undatedCount, 2);
    });

    test('are not counted as overdue as well', () {
      // Mutually exclusive: a debt cannot be both late and undated, and adding
      // it to both tallies would double-report it.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', dueOn: '2026-08-20'),
      ]);

      expect(summary.overdueCount, 1);
      expect(summary.undatedCount, 0);
    });
  });

  group('the soonest date', () {
    test('is the earliest one, whichever side it is on', () {
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'later', dueOn: '2026-10-30'),
        debt(
          id: 'sooner',
          direction: DebtDirection.owedToMe,
          dueOn: '2026-09-12',
        ),
      ]);

      expect(summary.soonest?.id, 'sooner');
    });

    test('includes one that is already late', () {
      // "What is next" for somebody already late is the thing they are already
      // late for. Skipping it to name a future date would be the card looking
      // past the problem.
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(id: 'late', dueOn: '2026-08-20'),
        debt(id: 'future'),
      ]);

      expect(summary.soonest?.id, 'late');
    });

    test('is null when nothing has a date at all', () {
      expect(
        DebtSummary.of(<DebtWithStatus>[debt(id: 'a', dueOn: null)]).soonest,
        isNull,
      );
    });

    test('skips settled debts', () {
      final DebtSummary summary = DebtSummary.of(<DebtWithStatus>[
        debt(
          id: 'done',
          dueOn: '2026-08-20',
          settledAt: '2026-08-21T01:00:00Z',
        ),
        debt(id: 'open'),
      ]);

      expect(summary.soonest?.id, 'open');
    });
  });

  test('nothing open is nothing to show', () {
    expect(DebtSummary.of(const <DebtWithStatus>[]).hasAnything, isFalse);
    expect(
      DebtSummary.of(<DebtWithStatus>[
        debt(id: 'a', settledAt: '2026-09-02T01:00:00Z'),
      ]).hasAnything,
      isFalse,
    );
  });
}
