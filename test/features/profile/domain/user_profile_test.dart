import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';

/// PayPaw's own row for an account.
///
/// Most of what is here is about one distinction: a name somebody **chose**
/// versus a login PayPaw guessed from. Blurring the two is how an app ends up
/// greeting people as "marcdelacruzesteban" and calling it personalisation.
void main() {
  group('the name', () {
    test('is absent until somebody gives one', () {
      const UserProfile profile = UserProfile(id: 'user-1');

      expect(profile.hasName, isFalse);
      expect(profile.name, isNull);
    });

    test('and a name of nothing but spaces is not one', () {
      // The column allows it and a paste can produce it. A blank heading is
      // worse than the fallback it would have replaced.
      const UserProfile profile = UserProfile(id: 'user-1', displayName: '   ');

      expect(profile.hasName, isFalse);
      expect(profile.name, isNull);
    });

    test('comes back trimmed', () {
      const UserProfile profile = UserProfile(
        id: 'user-1',
        displayName: '  Marc  ',
      );

      expect(profile.name, 'Marc');
    });
  });

  group('the initial', () {
    test('is the name, when there is one', () {
      expect(
        UserProfile.initialFor(name: 'Marc', email: 'other@example.com'),
        'M',
      );
    });

    test('and the address when there is not', () {
      expect(UserProfile.initialFor(email: 'marc@example.com'), 'M');
    });

    test('a blank name falls through to the address', () {
      expect(
        UserProfile.initialFor(name: '   ', email: 'marc@example.com'),
        'M',
      );
    });

    test('and with neither it does not crash', () {
      // A moment during sign-out, not a state worth designing for — but a
      // `substring` on an empty string is a crash on a screen nobody was using.
      expect(UserProfile.initialFor(), '?');
      expect(UserProfile.initialFor(name: '', email: ''), '?');
    });

    test('it is upper case whatever was typed', () {
      expect(UserProfile.initialFor(name: 'marc'), 'M');
    });
  });

  group('the defaults', () {
    test('match the column defaults', () {
      // Pinned to `0002_profiles.sql`. Two definitions of "Asia/Manila" that
      // drift is a user whose due dates are a day out with no way to tell.
      const UserProfile profile = UserProfile(id: 'user-1');

      expect(profile.currency, 'PHP');
      expect(profile.locale, 'en_PH');
      expect(profile.timeZone, 'Asia/Manila');
    });
  });

  group('copyWith', () {
    const UserProfile profile = UserProfile(
      id: 'user-1',
      displayName: 'Marc',
      timeZone: 'Europe/London',
    );

    test('leaves the untouched fields alone', () {
      expect(profile.copyWith(timeZone: 'Asia/Manila').displayName, 'Marc');
      expect(profile.copyWith(displayName: 'Mark').timeZone, 'Europe/London');
    });

    test('cannot change the id, because the profile is the user', () {
      expect(profile.copyWith(displayName: 'Mark').id, 'user-1');
    });

    test('and clearing the name is a different thing from not setting it', () {
      // `copyWith` cannot tell null from "not given", which is exactly the
      // distinction somebody deleting their name is making.
      expect(profile.copyWith(clearDisplayName: true).displayName, isNull);
      expect(profile.copyWith().displayName, 'Marc');
    });
  });

  test('two profiles are equal when every field is', () {
    expect(
      const UserProfile(id: 'user-1', displayName: 'Marc'),
      const UserProfile(id: 'user-1', displayName: 'Marc'),
    );
    expect(
      const UserProfile(id: 'user-1', displayName: 'Marc').hashCode,
      const UserProfile(id: 'user-1', displayName: 'Marc').hashCode,
    );
    expect(
      const UserProfile(id: 'user-1', displayName: 'Marc'),
      isNot(const UserProfile(id: 'user-1', displayName: 'Mark')),
    );
  });
}
