import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/profile/data/dtos/user_profile_dto.dart';
import 'package:paypaw/features/profile/domain/entities/user_profile.dart';

/// The mapper between `public.profiles` and the entity.
///
/// Hand-written, so every column name here is a string the compiler will never
/// check against `0002_profiles.sql`. A typo is a runtime failure on a device,
/// and this is the only place it can be caught.
void main() {
  group('toEntity', () {
    test('names the columns the migration declares', () {
      final UserProfile profile = UserProfileDto.toEntity(<String, dynamic>{
        'id': 'user-1',
        'display_name': 'Marc',
        'avatar_url': 'https://example.com/a.png',
        'currency': 'USD',
        'locale': 'en_US',
        'time_zone': 'Europe/London',
      });

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Marc');
      expect(profile.avatarUrl, 'https://example.com/a.png');
      expect(profile.currency, 'USD');
      expect(profile.locale, 'en_US');
      expect(profile.timeZone, 'Europe/London');
    });

    test('a blank name is no name', () {
      // The column allows the empty string. A name of zero characters would
      // render as a blank line where the heading goes.
      expect(
        UserProfileDto.toEntity(<String, dynamic>{
          'id': 'user-1',
          'display_name': '   ',
        }).displayName,
        isNull,
      );
    });

    test('and a name comes back trimmed', () {
      expect(
        UserProfileDto.toEntity(<String, dynamic>{
          'id': 'user-1',
          'display_name': '  Marc  ',
        }).displayName,
        'Marc',
      );
    });

    test('a row missing the newer columns still reads', () {
      // The column defaults cover a row this build wrote, but not one written
      // before a column existed. Falling back keeps a half-migrated profile
      // readable rather than failing the whole screen.
      final UserProfile profile = UserProfileDto.toEntity(<String, dynamic>{
        'id': 'user-1',
      });

      expect(profile.currency, 'PHP');
      expect(profile.locale, 'en_PH');
      expect(profile.timeZone, 'Asia/Manila');
    });

    test('and a blank time zone falls back rather than being empty', () {
      // An empty zone would be passed to `bill_status`, which would then have
      // no idea what day it is for this user.
      expect(
        UserProfileDto.toEntity(<String, dynamic>{
          'id': 'user-1',
          'time_zone': '',
        }).timeZone,
        'Asia/Manila',
      );
    });
  });

  group('the updates', () {
    test('a name update carries the name and nothing else', () {
      // A patch, not the whole row. An update that writes columns nobody edited
      // is an update that can undo something another device changed.
      expect(UserProfileDto.toDisplayNameUpdate('Marc'), <String, dynamic>{
        'display_name': 'Marc',
      });
    });

    test('an empty name clears it rather than storing blank', () {
      expect(UserProfileDto.toDisplayNameUpdate('   '), <String, dynamic>{
        'display_name': null,
      });
      expect(UserProfileDto.toDisplayNameUpdate(null), <String, dynamic>{
        'display_name': null,
      });
    });

    test('and a zone update carries the zone and nothing else', () {
      expect(
        UserProfileDto.toTimeZoneUpdate('Europe/London'),
        <String, dynamic>{'time_zone': 'Europe/London'},
      );
    });

    test('neither one sends the id, currency or locale', () {
      // The id is the primary key and currency is not offered as a setting —
      // changing it converts nothing and would silently reinterpret every
      // amount already stored.
      for (final Map<String, dynamic> update in <Map<String, dynamic>>[
        UserProfileDto.toDisplayNameUpdate('Marc'),
        UserProfileDto.toTimeZoneUpdate('Europe/London'),
      ]) {
        expect(update.keys, isNot(contains('id')));
        expect(update.keys, isNot(contains('currency')));
        expect(update.keys, isNot(contains('locale')));
      }
    });
  });
}
