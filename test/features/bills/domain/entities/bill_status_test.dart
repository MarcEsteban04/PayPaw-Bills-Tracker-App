import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';

/// The status enum and the two questions the UI asks it.
///
/// Worth its own file because the wire values have to match the `case` expression
/// in `supabase/migrations/0015_bill_status_due_today.sql` exactly. A typo there
/// is not a compile error — it is a status that silently parses to null and
/// renders as "Unknown".
void main() {
  group('tryParse', () {
    test('reads every value the view can produce', () {
      // This list is the view's case expression, written out. If the two ever
      // disagree, one of them is wrong and this is where it shows.
      const Map<String, BillStatus> wire = <String, BillStatus>{
        'upcoming': BillStatus.upcoming,
        'due_soon': BillStatus.dueSoon,
        'due_today': BillStatus.dueToday,
        'partially_paid': BillStatus.partiallyPaid,
        'overdue': BillStatus.overdue,
        'paid': BillStatus.paid,
        'archived': BillStatus.archived,
      };

      wire.forEach((String value, BillStatus expected) {
        expect(BillStatus.tryParse(value), expected, reason: value);
      });
    });

    test('every status is covered by that list', () {
      // Catches the other direction: a status added to the enum and forgotten
      // here would otherwise leave this file quietly incomplete.
      expect(BillStatus.values, hasLength(7));
    });

    test('an unknown value is null, not a throw and not a guess', () {
      // A status added to the view before the app is updated should surface as
      // "unknown" on a screen the user was only reading. A wrong status is worse
      // than none.
      expect(BillStatus.tryParse('cancelled'), isNull);
      expect(BillStatus.tryParse(null), isNull);
      expect(BillStatus.tryParse(''), isNull);
    });
  });

  group('isOutstanding', () {
    test('is true for everything that still needs money', () {
      expect(BillStatus.upcoming.isOutstanding, isTrue);
      expect(BillStatus.dueSoon.isOutstanding, isTrue);
      expect(BillStatus.dueToday.isOutstanding, isTrue);
      expect(BillStatus.partiallyPaid.isOutstanding, isTrue);
      expect(BillStatus.overdue.isOutstanding, isTrue);
    });

    test('and false for the two that do not', () {
      expect(BillStatus.paid.isOutstanding, isFalse);
      // Archived is excluded from the totals: the user put it away, and counting
      // it would make the denominator include work nobody intends to do.
      expect(BillStatus.archived.isOutstanding, isFalse);
    });
  });

  group('needsAttention', () {
    test('covers today as well as late and close', () {
      // Due-today was the gap. It landed in due_soon's three-day window, so a
      // bill due this afternoon and one due on Friday said the same thing.
      expect(BillStatus.overdue.needsAttention, isTrue);
      expect(BillStatus.dueToday.needsAttention, isTrue);
      expect(BillStatus.dueSoon.needsAttention, isTrue);
    });

    test('and not the ones with time left or nothing owed', () {
      expect(BillStatus.upcoming.needsAttention, isFalse);
      expect(BillStatus.paid.needsAttention, isFalse);
      expect(BillStatus.archived.needsAttention, isFalse);
      // Partly paid ranks below the dates in the view now, so reaching this
      // status at all means there is no date pressure.
      expect(BillStatus.partiallyPaid.needsAttention, isFalse);
    });
  });

  group('urgency', () {
    test('ranks date pressure above a part payment, and finished last', () {
      // The same order the bills list groups in and the view ranks by. A
      // calendar square shows the loudest bill on its day, so two screens now
      // depend on this agreeing with itself.
      final List<BillStatus> byUrgency = BillStatus.values.toList()
        ..sort((BillStatus a, BillStatus b) => a.urgency.compareTo(b.urgency));

      expect(byUrgency, <BillStatus>[
        BillStatus.overdue,
        BillStatus.dueToday,
        BillStatus.dueSoon,
        BillStatus.partiallyPaid,
        BillStatus.upcoming,
        BillStatus.paid,
        BillStatus.archived,
      ]);
    });

    test('every status has its own rank', () {
      // Two statuses sharing a rank would make "the loudest" depend on the order
      // the bills happened to arrive in.
      final Set<int> ranks = BillStatus.values
          .map((BillStatus s) => s.urgency)
          .toSet();

      expect(ranks, hasLength(BillStatus.values.length));
    });
  });

  group('the loudest of several', () {
    test('a day with one overdue bill among settled ones is overdue', () {
      expect(
        BillStatus.mostUrgent(<BillStatus?>[
          BillStatus.paid,
          BillStatus.overdue,
          BillStatus.paid,
        ]),
        BillStatus.overdue,
      );
    });

    test('and one where everything is settled is settled', () {
      expect(
        BillStatus.mostUrgent(<BillStatus?>[BillStatus.paid, BillStatus.paid]),
        BillStatus.paid,
      );
    });

    test('order does not matter', () {
      expect(
        BillStatus.mostUrgent(<BillStatus?>[
          BillStatus.dueSoon,
          BillStatus.upcoming,
        ]),
        BillStatus.mostUrgent(<BillStatus?>[
          BillStatus.upcoming,
          BillStatus.dueSoon,
        ]),
      );
    });

    test('an unrecognised status is skipped rather than ranked', () {
      // Null is a status the view emits that this build has not been taught.
      // There is nothing to rank it by, and letting it win would colour a square
      // by a value nobody can name.
      expect(
        BillStatus.mostUrgent(<BillStatus?>[null, BillStatus.upcoming]),
        BillStatus.upcoming,
      );
    });

    test('and nothing at all is null', () {
      expect(BillStatus.mostUrgent(const <BillStatus?>[]), isNull);
      expect(BillStatus.mostUrgent(<BillStatus?>[null]), isNull);
    });
  });
}
