import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/debts/domain/entities/debt.dart';
import 'package:paypaw/features/debts/domain/entities/debt_direction.dart';
import 'package:paypaw/features/debts/domain/entities/new_debt.dart';

/// Utang, in both directions.
///
/// The rules worth pinning down are the two that differ from a bill: a debt may
/// have **no agreed date at all**, and a direction that cannot be read is refused
/// rather than guessed.
void main() {
  final DateTime today = DateTime(2026, 9, 3);

  Debt debt({
    DebtDirection direction = DebtDirection.iOwe,
    DateTime? dueOn,
    DateTime? settledAt,
  }) => Debt(
    id: 'debt-1',
    userId: 'user-1',
    direction: direction,
    counterpartyName: 'Tita Ana',
    principal: const Money.php(500000),
    incurredOn: DateTime(2026, 8, 12),
    dueOn: dueOn,
    settledAt: settledAt,
    createdAt: DateTime(2026, 8, 12),
    updatedAt: DateTime(2026, 8, 12),
  );

  group('direction', () {
    test('round-trips through its stored value', () {
      for (final DebtDirection direction in DebtDirection.values) {
        expect(DebtDirection.parse(direction.wireValue), direction);
      }
    });

    test('refuses anything else rather than guessing', () {
      // Unlike a recurring bill's `kind`, which defaults to `bill` because a
      // template the app cannot classify still has to appear somewhere. Telling
      // somebody they owe ₱5,000 when they are owed ₱5,000 is a two-way error on
      // the one fact this feature exists to record.
      expect(DebtDirection.parse('owes_me'), isNull);
      expect(DebtDirection.parse(''), isNull);
      expect(DebtDirection.parse(null), isNull);
    });

    test('knows which way is out, and what the other way is', () {
      expect(DebtDirection.iOwe.isOutgoing, isTrue);
      expect(DebtDirection.owedToMe.isOutgoing, isFalse);
      expect(DebtDirection.iOwe.opposite, DebtDirection.owedToMe);
      expect(DebtDirection.owedToMe.opposite, DebtDirection.iOwe);
    });
  });

  group('being late', () {
    test('is only possible once the agreed date has passed', () {
      expect(debt(dueOn: DateTime(2026, 9, 2)).isOverdue(today), isTrue);
      expect(debt(dueOn: DateTime(2026, 9, 4)).isOverdue(today), isFalse);
    });

    test('does not start on the day itself', () {
      // A bill due today is not yet late, and neither is a debt. The day is
      // still going.
      expect(debt(dueOn: today).isOverdue(today), isFalse);
    });

    test('never applies to a debt nobody agreed a date for', () {
      // The case that separates utang from a bill. Nothing was promised, so
      // nothing has been broken — and treating "no date" as "overdue since day
      // one" would paint half of somebody's informal lending red.
      expect(debt().isOverdue(today), isFalse);
      expect(debt().hasDueDate, isFalse);
    });

    test('and never to one already repaid', () {
      expect(
        debt(
          dueOn: DateTime(2026, 1, 20),
          settledAt: DateTime(2026, 2, 20),
        ).isOverdue(today),
        isFalse,
      );
    });
  });

  group('settling', () {
    test('is what open means', () {
      expect(debt().isOpen, isTrue);
      expect(debt(settledAt: DateTime(2026, 9, 2)).isSettled, isTrue);
    });

    test('is undone by clearing, which copyWith cannot do', () {
      // `copyWith` reads a null as "leave it alone", so reopening a debt has to
      // say so explicitly.
      final Debt settled = debt(settledAt: DateTime(2026, 9, 2));

      expect(settled.copyWith().settledAt, isNotNull);
      expect(settled.clearing(settledAt: true).settledAt, isNull);
    });
  });

  group('a draft', () {
    NewDebt draft({
      String name = 'Tita Ana',
      int principalMinor = 500000,
      DateTime? dueOn,
      String? contact,
      String? notes,
    }) => NewDebt(
      direction: DebtDirection.iOwe,
      counterpartyName: name,
      counterpartyContact: contact,
      principal: Money.php(principalMinor),
      incurredOn: DateTime(2026, 8, 12),
      dueOn: dueOn,
      notes: notes,
    );

    test('needs somebody on the other side of it', () {
      expect(draft(name: '   ').validate(), isNotNull);
      expect(draft(name: 'x' * 121).validate(), isNotNull);
      expect(draft().validate(), isNull);
    });

    test('needs an amount greater than nothing', () {
      // Stricter than a bill, whose column allows zero so a placeholder for a
      // varying charge can exist. There is no version of a debt for ₱0 that
      // anybody would record.
      expect(draft(principalMinor: 0).validate(), isNotNull);
    });

    test('may have no repayment date', () {
      expect(draft().validate(), isNull);
    });

    test('but not one before the money changed hands', () {
      expect(draft(dueOn: DateTime(2026, 8, 11)).validate(), isNotNull);
      // The same day is fine: money lent in the morning and due that evening is
      // unusual, not impossible.
      expect(draft(dueOn: DateTime(2026, 8, 12)).validate(), isNull);
    });

    test('caps the contact and the notes', () {
      expect(draft(contact: 'x' * 121).validate(), isNotNull);
      expect(draft(notes: 'x' * 2001).validate(), isNotNull);
      expect(draft(contact: '0917 555 1234').validate(), isNull);
    });
  });
}
