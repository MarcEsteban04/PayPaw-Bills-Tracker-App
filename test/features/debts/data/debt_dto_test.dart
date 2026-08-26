import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/debts/data/dtos/debt_dto.dart';
import 'package:paypaw/features/debts/domain/entities/debt.dart';
import 'package:paypaw/features/debts/domain/entities/debt_direction.dart';
import 'package:paypaw/features/debts/domain/entities/new_debt.dart';

/// The mapping between `public.debts` and [Debt].
///
/// Worth testing precisely because it is the layer where a mistake is a
/// *runtime* failure rather than a compile error: a column name that does not
/// match `0008_debts.sql` type-checks perfectly and fails on a real device.
void main() {
  Map<String, dynamic> row({
    String direction = 'i_owe',
    Object? dueOn = '2026-09-30',
    Object? contact = '0917 555 1234',
    Object? settledAt,
  }) => <String, dynamic>{
    'id': 'debt-1',
    'user_id': 'user-1',
    'direction': direction,
    'counterparty_name': 'Tita Ana',
    'counterparty_contact': contact,
    'principal_minor': 500000,
    'currency': 'PHP',
    'incurred_on': '2026-08-12',
    'due_on': dueOn,
    'notes': 'For the tuition',
    'settled_at': settledAt,
    'created_at': '2026-08-12T02:30:00Z',
    'updated_at': '2026-08-12T02:30:00Z',
  };

  group('reading a row', () {
    test('maps every stored fact', () {
      final Debt debt = DebtDto.toEntity(row());

      expect(debt.id, 'debt-1');
      expect(debt.direction, DebtDirection.iOwe);
      expect(debt.counterpartyName, 'Tita Ana');
      expect(debt.counterpartyContact, '0917 555 1234');
      expect(debt.principal, const Money.php(500000));
      expect(debt.incurredOn, DateTime(2026, 8, 12));
      expect(debt.dueOn, DateTime(2026, 9, 30));
      expect(debt.notes, 'For the tuition');
      expect(debt.isOpen, isTrue);
    });

    test('reads a date as a local midnight, not an instant', () {
      // Through `DateTime.parse` alone a date-only column becomes midnight UTC,
      // which is the previous evening in Manila — so a debt due on the 30th
      // would render as the 29th for every user east of Greenwich.
      final Debt debt = DebtDto.toEntity(row());

      expect(debt.dueOn!.hour, 0);
      expect(debt.dueOn!.isUtc, isFalse);
    });

    test('accepts a debt with no agreed date', () {
      expect(DebtDto.toEntity(row(dueOn: null)).dueOn, isNull);
      expect(DebtDto.toEntity(row(dueOn: '')).dueOn, isNull);
    });

    test('accepts a debt with no contact recorded', () {
      expect(DebtDto.toEntity(row(contact: null)).counterpartyContact, isNull);
    });

    test('reads the other direction too', () {
      expect(
        DebtDto.toEntity(row(direction: 'owed_to_me')).direction,
        DebtDirection.owedToMe,
      );
    });

    test('refuses a direction it cannot read', () {
      // Rather than defaulting. A row that cannot say which way the money goes
      // is worse than absent: guessing tells somebody they owe money they are
      // in fact owed.
      expect(
        () => DebtDto.toEntity(row(direction: 'owes_me')),
        throwsA(isA<FormatException>()),
      );
    });

    test('carries settled_at through', () {
      final Debt debt = DebtDto.toEntity(
        row(settledAt: '2026-09-02T01:00:00Z'),
      );

      expect(debt.isSettled, isTrue);
    });
  });

  group('writing an insert', () {
    final NewDebt draft = NewDebt(
      direction: DebtDirection.owedToMe,
      counterpartyName: '  Kuya Ben  ',
      counterpartyContact: '   ',
      principal: const Money.php(150000),
      incurredOn: DateTime(2026, 8, 12),
      dueOn: DateTime(2026, 9, 30),
      notes: '  ',
    );

    test('sends the direction as its stored value', () {
      expect(
        DebtDto.toInsert(draft, userId: 'user-1')['direction'],
        'owed_to_me',
      );
    });

    test('takes the owner from the caller, never from the draft', () {
      // `NewDebt` deliberately has no owner: the repository takes it from the
      // session so no call site can pass somebody else's.
      expect(DebtDto.toInsert(draft, userId: 'user-1')['user_id'], 'user-1');
    });

    test('trims the name and nulls the blank optional fields', () {
      final Map<String, dynamic> values = DebtDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['counterparty_name'], 'Kuya Ben');
      // Empty is not the same as absent. A blank contact stored as '' formats
      // later as a stray blank line under the name.
      expect(values['counterparty_contact'], isNull);
      expect(values['notes'], isNull);
    });

    test('sends dates as date-only strings', () {
      final Map<String, dynamic> values = DebtDto.toInsert(
        draft,
        userId: 'user-1',
      );

      expect(values['incurred_on'], '2026-08-12');
      expect(values['due_on'], '2026-09-30');
    });

    test('omits a due date that was never agreed', () {
      final NewDebt undated = NewDebt(
        direction: DebtDirection.iOwe,
        counterpartyName: 'Tita Ana',
        principal: const Money.php(500000),
        incurredOn: DateTime(2026, 8, 12),
      );

      expect(DebtDto.toInsert(undated, userId: 'user-1')['due_on'], isNull);
    });

    test('does not send settled_at — a debt is not created repaid', () {
      expect(
        DebtDto.toInsert(draft, userId: 'user-1').containsKey('settled_at'),
        isFalse,
      );
    });
  });

  group('writing an update', () {
    test('never sends the owner', () {
      // Ownership is not an editable property, and sending it would be an
      // update the RLS policy has to reject rather than one it never sees.
      final Debt debt = DebtDto.toEntity(row());

      expect(DebtDto.toUpdate(debt).containsKey('user_id'), isFalse);
      expect(DebtDto.toUpdate(debt).containsKey('id'), isFalse);
    });

    test('does send settled_at, because reopening is a null', () {
      final Debt settled = DebtDto.toEntity(
        row(settledAt: '2026-09-02T01:00:00Z'),
      );

      expect(DebtDto.toUpdate(settled)['settled_at'], isNotNull);
      expect(
        DebtDto.toUpdate(settled.clearing(settledAt: true))['settled_at'],
        isNull,
      );
    });
  });

  test('every column it selects is one it can read back', () {
    // The select list and the reader drifting apart is the failure this file
    // exists to catch: a column dropped from `selectColumns` still type-checks
    // and then arrives as a missing key on a device.
    final Set<String> selected = DebtDto.selectColumns
        .split(',')
        .map((String column) => column.trim())
        .toSet();

    expect(selected, row().keys.toSet());
  });
}
