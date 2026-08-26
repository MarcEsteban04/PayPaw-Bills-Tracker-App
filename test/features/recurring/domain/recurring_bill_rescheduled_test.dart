import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence.dart';
import 'package:paypaw/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';

/// What changing a schedule does to the bookmark.
///
/// `next_due_on` is a bookmark rather than a derived value, which is what makes
/// generation idempotent — and what makes editing a rule dangerous. A bookmark
/// left pointing at a date the new rule never produces is a schedule that either
/// stops generating forever or generates on a day nobody chose.
///
/// The rule this file pins down is: **never earlier than it already was.**
/// Everything before the bookmark has been billed, and a bookmark that moved
/// backwards would bill it again.
void main() {
  RecurringBill template({
    required Recurrence recurrence,
    required DateTime nextDueOn,
    bool isActive = true,
  }) => RecurringBill(
    id: 'rec-1',
    userId: 'user-1',
    kind: RecurringBillKind.subscription,
    name: 'Netflix',
    amount: const Money.php(54900),
    recurrence: recurrence,
    nextDueOn: nextDueOn,
    isActive: isActive,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  Recurrence monthlyOn(int day, {DateTime? from, DateTime? until}) =>
      Recurrence(
        frequency: RecurrenceFrequency.monthly,
        startsOn: from ?? DateTime(2026, 1, 18),
        dayOfMonth: day,
        endsOn: until,
      );

  test('keeps the bookmark when the rule still produces that day', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    // Editing the amount and leaving the schedule alone still runs through
    // here, and must not move the next charge by a day.
    expect(
      original.rescheduled(monthlyOn(18)).nextDueOn,
      DateTime(2026, 9, 18),
    );
  });

  test('a coarser cycle skips forward to the next date it produces', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    // Quarterly from January produces January, April, July, October — not
    // September. The bookmark goes to October rather than staying on a date the
    // rule would never generate and never advance past.
    final Recurrence quarterly = Recurrence(
      frequency: RecurrenceFrequency.monthly,
      startsOn: DateTime(2026, 1, 18),
      intervalCount: 3,
      dayOfMonth: 18,
    );

    expect(original.rescheduled(quarterly).nextDueOn, DateTime(2026, 10, 18));
  });

  test('moves the bookmark to the new day of the month', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    // The 25th is the first date the new rule produces on or after the old
    // bookmark, so the next charge slides within the same month rather than
    // jumping to October.
    expect(
      original.rescheduled(monthlyOn(25)).nextDueOn,
      DateTime(2026, 9, 25),
    );
  });

  test('moving the start forward delays the next charge', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    final RecurringBill moved = original.rescheduled(
      monthlyOn(18, from: DateTime(2026, 12, 18)),
    );

    expect(moved.nextDueOn, DateTime(2026, 12, 18));
    expect(moved.isActive, isTrue);
  });

  test('moving the start backwards does not regenerate billed months', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    // The rule now claims to have started in 2024. Everything up to September
    // has already been generated, and honouring the new start would produce a
    // year and a half of bills the user has already paid.
    expect(
      original
          .rescheduled(monthlyOn(18, from: DateTime(2024, 1, 18)))
          .nextDueOn,
      DateTime(2026, 9, 18),
    );
  });

  test('a rule with nothing left to produce comes back paused', () {
    final RecurringBill original = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
    );

    final RecurringBill ended = original.rescheduled(
      monthlyOn(18, until: DateTime(2026, 7, 20)),
    );

    // Paused rather than left generating, and the bookmark is untouched: a
    // stopped schedule, which is what an end date in the past means even when
    // the user did not phrase it that way.
    expect(ended.isActive, isFalse);
    expect(ended.nextDueOn, DateTime(2026, 9, 18));
  });

  test('editing a paused schedule does not resume it', () {
    final RecurringBill paused = template(
      recurrence: monthlyOn(18),
      nextDueOn: DateTime(2026, 9, 18),
      isActive: false,
    );

    expect(paused.rescheduled(monthlyOn(25)).isActive, isFalse);
  });
}
