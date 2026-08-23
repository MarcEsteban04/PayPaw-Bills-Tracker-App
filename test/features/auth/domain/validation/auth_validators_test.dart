import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/auth/domain/validation/auth_validators.dart';

/// The credential rules are pure functions, so they get the thorough treatment:
/// they are cheap to test, three screens depend on them, and a rule that is
/// wrong here is wrong everywhere at once.
void main() {
  group('email', () {
    test('accepts ordinary addresses', () {
      for (final String address in <String>[
        'marc@example.com',
        'marc.esteban@example.co.uk',
        'marc+bills@example.com',
        'm@e.io',
      ]) {
        expect(
          AuthValidators.email(address),
          isNull,
          reason: '$address should be accepted',
        );
      }
    });

    test('rejects what is obviously not an address', () {
      for (final String address in <String>[
        '',
        '   ',
        'marc',
        'marc@',
        '@example.com',
        'marc@example',
        'marc example@test.com',
        'marc@@example.com',
      ]) {
        expect(
          AuthValidators.email(address),
          isNotNull,
          reason: '$address should be rejected',
        );
      }
    });

    test('rejects null', () {
      expect(AuthValidators.email(null), isNotNull);
    });

    test('ignores surrounding whitespace', () {
      // People paste addresses with a trailing space constantly.
      expect(AuthValidators.email('  marc@example.com  '), isNull);
    });

    test(
      'asks for an address when empty, rather than complaining about format',
      () {
        expect(AuthValidators.email(''), 'Enter your email address');
      },
    );
  });

  group('password', () {
    test('accepts one meeting every rule', () {
      expect(AuthValidators.password('paypaw2026'), isNull);
    });

    test('rejects an empty password', () {
      expect(AuthValidators.password(''), 'Choose a password');
      expect(AuthValidators.password(null), 'Choose a password');
    });

    test('reports the length rule first', () {
      // One message at a time, and the most fundamental one first: telling
      // someone their 3-character password needs a number is unhelpful.
      expect(
        AuthValidators.password('ab1'),
        contains('${AuthValidators.minPasswordLength} characters'),
      );
    });

    test('requires a letter', () {
      expect(AuthValidators.password('12345678'), contains('letter'));
    });

    test('requires a number', () {
      expect(AuthValidators.password('abcdefgh'), contains('number'));
    });

    test('accepts exactly the minimum length', () {
      expect(AuthValidators.password('abcdefg1'), isNull);
    });

    test('does not trim', () {
      // A space is a legitimate password character. Stripping it would lock the
      // user out of the account they just created.
      expect(AuthValidators.password(' abcdefg1'), isNull);
      expect(AuthValidators.password('abcdefg1 '), isNull);
    });
  });

  group('password confirmation', () {
    test('accepts a match', () {
      expect(
        AuthValidators.passwordConfirmation('paypaw2026', 'paypaw2026'),
        isNull,
      );
    });

    test('rejects a mismatch', () {
      expect(
        AuthValidators.passwordConfirmation('paypaw2026', 'paypaw2027'),
        contains('do not match'),
      );
    });

    test('rejects an empty confirmation', () {
      expect(
        AuthValidators.passwordConfirmation('', 'paypaw2026'),
        contains('Re-enter'),
      );
      expect(
        AuthValidators.passwordConfirmation(null, 'paypaw2026'),
        contains('Re-enter'),
      );
    });

    test('is case sensitive', () {
      expect(
        AuthValidators.passwordConfirmation('PayPaw2026', 'paypaw2026'),
        isNotNull,
      );
    });
  });

  group('requirements', () {
    test('reports each rule separately', () {
      expect(AuthValidators.requirements('abcdefg1'), (
        hasMinLength: true,
        hasLetter: true,
        hasNumber: true,
      ));
      expect(AuthValidators.requirements('abc'), (
        hasMinLength: false,
        hasLetter: true,
        hasNumber: false,
      ));
      expect(AuthValidators.requirements('12345678'), (
        hasMinLength: true,
        hasLetter: false,
        hasNumber: true,
      ));
      expect(AuthValidators.requirements(''), (
        hasMinLength: false,
        hasLetter: false,
        hasNumber: false,
      ));
    });

    test('agrees with the validator', () {
      // The checklist and the error message must never disagree — a checklist
      // showing three ticks above "use at least 8 characters" is worse than no
      // checklist.
      for (final String password in <String>[
        '',
        'abc',
        'abcdefgh',
        '12345678',
        'abcdefg1',
      ]) {
        final PasswordRequirements met = AuthValidators.requirements(password);
        final bool allMet = met.hasMinLength && met.hasLetter && met.hasNumber;

        expect(
          AuthValidators.password(password) == null,
          allMet,
          reason: 'checklist and validator disagree on "$password"',
        );
      }
    });
  });
}
