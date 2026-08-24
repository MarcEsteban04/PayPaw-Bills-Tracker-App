import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/domain/money.dart';
import 'package:paypaw/features/payments/domain/validation/payment_validators.dart';

/// The rules on a payment somebody is typing.
///
/// The amount rules mirror `BillValidators`. The date rule does not, and that is
/// the interesting half: a bill may be due in 2035, but no payment has happened
/// tomorrow — and one dated tomorrow settles a bill on a screen while the money
/// is still in the account.
void main() {
  final DateTime today = DateTime(2026, 8, 25);

  group('the amount', () {
    test('has to be there', () {
      expect(PaymentValidators.amount(''), isNotNull);
      expect(PaymentValidators.amount('   '), isNotNull);
      expect(PaymentValidators.amount(null), isNotNull);
    });

    test('has to be a number', () {
      expect(PaymentValidators.amount('abc'), isNotNull);
      expect(PaymentValidators.amount('12.345'), isNotNull);
    });

    test('has to be more than nothing', () {
      // The column refuses both. A nil payment is not a payment and a refund is
      // not a negative one — modelling either that way makes every sum a guess.
      expect(PaymentValidators.amount('0'), isNotNull);
      expect(PaymentValidators.amount('0.00'), isNotNull);
      expect(PaymentValidators.amount('-50'), isNotNull);
    });

    test('and passes what a person actually types', () {
      expect(PaymentValidators.amount('1250.50'), isNull);
      expect(PaymentValidators.amount('1,250.5'), isNull);
      expect(PaymentValidators.amount('3000'), isNull);
    });
  });

  group('the date', () {
    test('cannot be in the future', () {
      expect(
        PaymentValidators.paidAt(DateTime(2026, 8, 26), today: today),
        isNotNull,
      );
    });

    test('but today is fine, whatever the time of day', () {
      // Compared by date, not by instant. Recorded at 9pm for "today", an
      // instant comparison would call it the future a fraction of a second on.
      expect(
        PaymentValidators.paidAt(DateTime(2026, 8, 25, 21, 30), today: today),
        isNull,
      );
    });

    test('and the past is fine until the year looks mistyped', () {
      expect(
        PaymentValidators.paidAt(DateTime(2025, 12, 31), today: today),
        isNull,
      );
      expect(
        PaymentValidators.paidAt(DateTime(2010, 8, 25), today: today),
        isNotNull,
      );
    });

    test('and it has to be chosen at all', () {
      expect(PaymentValidators.paidAt(null, today: today), isNotNull);
    });
  });

  group('overpaying', () {
    const Money owed = Money.php(150000);

    test('warns rather than refusing', () {
      // A surcharge, a rounded-up transfer, a bill two people both paid. The
      // column permits it, and refusing here would leave somebody unable to
      // record what their statement says.
      final String? warning = PaymentValidators.overpaymentWarning(
        '2000',
        owed: owed,
      );

      expect(warning, isNotNull);
      expect(warning, contains('₱1,500.00'));
      // The field itself is still valid, which is what keeps Save alive.
      expect(PaymentValidators.amount('2000'), isNull);
    });

    test('says nothing about paying exactly what is owed', () {
      expect(PaymentValidators.overpaymentWarning('1500', owed: owed), isNull);
    });

    test('nor about paying part of it', () {
      expect(PaymentValidators.overpaymentWarning('500', owed: owed), isNull);
    });

    test('and nothing at all while the field is mid-typing', () {
      // An empty or half-typed field is the amount validator's business. A
      // warning here would flicker on every keystroke.
      expect(PaymentValidators.overpaymentWarning('', owed: owed), isNull);
      expect(PaymentValidators.overpaymentWarning('abc', owed: owed), isNull);
    });
  });

  group('isComplete', () {
    test('is true when every field passes', () {
      expect(
        PaymentValidators.isComplete(
          amount: '500',
          paidAt: today,
          today: today,
        ),
        isTrue,
      );
    });

    test('and false when any one of them does not', () {
      expect(
        PaymentValidators.isComplete(amount: '0', paidAt: today, today: today),
        isFalse,
      );
      expect(
        PaymentValidators.isComplete(
          amount: '500',
          paidAt: DateTime(2026, 9, 4),
          today: today,
        ),
        isFalse,
      );
      expect(
        PaymentValidators.isComplete(
          amount: '500',
          paidAt: today,
          today: today,
          reference: 'x' * (PaymentValidators.maxReferenceLength + 1),
        ),
        isFalse,
      );
    });
  });
}
