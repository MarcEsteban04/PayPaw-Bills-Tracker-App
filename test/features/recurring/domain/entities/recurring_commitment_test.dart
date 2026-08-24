import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_commitment.dart';

/// Normalising repeating bills to one month.
///
/// The arithmetic behind the dashboard's "Every month" figure. Worth its own
/// tests because it is the only number on that screen that is not in any row —
/// nothing else on the app would catch it being wrong.
void main() {
  RecurringBill template({
    required RecurrenceFrequency frequency,
    required int amount,
    String id = 'rec-1',
    int interval = 1,
    bool isActive = true,
    DateTime? endsOn,
    DateTime? nextDueOn,
  }) => RecurringBill(
    id: id,
    userId: 'user-1',
    kind: RecurringBillKind.bill,
    name: 'Template $id',
    amount: Money.php(amount),
    recurrence: Recurrence(
      frequency: frequency,
      intervalCount: interval,
      dayOfMonth: frequency == RecurrenceFrequency.weekly ? null : 15,
      weekday: frequency == RecurrenceFrequency.weekly ? DateTime.monday : null,
      monthOfYear: frequency == RecurrenceFrequency.yearly ? 3 : null,
      startsOn: DateTime(2026, 1, 5),
      endsOn: endsOn,
    ),
    nextDueOn: nextDueOn ?? DateTime(2026, 2, 15),
    isActive: isActive,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  group('normalising one template', () {
    test('a monthly bill is itself', () {
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(frequency: RecurrenceFrequency.monthly, amount: 400000),
        ],
      );

      expect(commitment.perMonth, const Money.php(400000));
      expect(commitment.perYear, const Money.php(4800000));
    });

    test('a yearly bill is a twelfth', () {
      // The point of the whole figure: ₱6,000 once a year and ₱500 a month are
      // the same commitment, and adding them as written is a number that means
      // nothing.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(frequency: RecurrenceFrequency.yearly, amount: 600000),
        ],
      );

      expect(commitment.perMonth, const Money.php(50000));
    });

    test('a quarterly bill is a third', () {
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(frequency: RecurrenceFrequency.quarterly, amount: 300000),
        ],
      );

      expect(commitment.perMonth, const Money.php(100000));
    });

    test('a weekly bill uses 365.25 days, not 52 weeks', () {
      // 52 loses a week every five years, which on something charged weekly is
      // a real amount. ₱1,000 a week is 52.18 weeks a year, so ₱4,348 a month.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(frequency: RecurrenceFrequency.weekly, amount: 100000),
        ],
      );

      expect(commitment.perMonth.minorUnits, 434821);
      // The 52-week shortcut would have said this instead.
      expect(commitment.perMonth.minorUnits, isNot(433333));
    });

    test('an interval divides it', () {
      // Every two months is half a monthly bill.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(
            frequency: RecurrenceFrequency.monthly,
            amount: 400000,
            interval: 2,
          ),
        ],
      );

      expect(commitment.perMonth, const Money.php(200000));
    });
  });

  group('what counts', () {
    test('a paused template is not a commitment', () {
      // A schedule the user stopped is not money they have to find, and counting
      // it would inflate the figure they budget against.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(
            frequency: RecurrenceFrequency.monthly,
            amount: 400000,
            isActive: false,
          ),
        ],
      );

      expect(commitment.hasAnything, isFalse);
      expect(commitment.perMonth, const Money.php(0));
      expect(commitment.activeCount, 0);
    });

    test('nor is one that has already finished', () {
      // Its bookmark is past its own end date, which is how a finished schedule
      // records that it is finished.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          template(
            frequency: RecurrenceFrequency.monthly,
            amount: 400000,
            endsOn: DateTime(2026, 1, 20),
            nextDueOn: DateTime(2026, 2, 15),
          ),
        ],
      );

      expect(commitment.activeCount, 0);
    });

    test('nothing at all is zero rather than an error', () {
      final RecurringCommitment commitment = RecurringCommitment.of(
        const <RecurringBill>[],
      );

      expect(commitment.hasAnything, isFalse);
      expect(commitment.perMonth, const Money.php(0));
      expect(commitment.largest, isNull);
    });
  });

  group('several together', () {
    final List<RecurringBill> mixed = <RecurringBill>[
      template(
        id: 'rent',
        frequency: RecurrenceFrequency.monthly,
        amount: 400000,
      ),
      template(
        id: 'internet',
        frequency: RecurrenceFrequency.monthly,
        amount: 150000,
      ),
      template(
        id: 'insurance',
        frequency: RecurrenceFrequency.yearly,
        amount: 600000,
      ),
    ];

    test('add up across their different units', () {
      // ₱4,000 + ₱1,500 monthly, plus ₱6,000 a year as ₱500.
      final RecurringCommitment commitment = RecurringCommitment.of(mixed);

      expect(commitment.perMonth, const Money.php(600000));
      expect(commitment.activeCount, 3);
    });

    test('and the biggest is named by what it costs a year, not per bill', () {
      // Rent at ₱4,000 a month outweighs insurance at ₱6,000 a year, even though
      // the single insurance bill is larger.
      expect(RecurringCommitment.of(mixed).largest?.id, 'rent');
    });

    test('the total is rounded once, not per template', () {
      // Rounding each first and summing drifts by up to half a centavo per bill,
      // which shows as a total that does not match its own parts.
      final RecurringCommitment commitment = RecurringCommitment.of(
        <RecurringBill>[
          for (int i = 0; i < 3; i++)
            template(
              id: 'yearly-$i',
              frequency: RecurrenceFrequency.yearly,
              // 100 minor units a year is 8.333 a month. Three of them is 25
              // exactly; rounding each to 8 first would give 24.
              amount: 100,
            ),
        ],
      );

      expect(commitment.perMonth.minorUnits, 25);
    });
  });
}
