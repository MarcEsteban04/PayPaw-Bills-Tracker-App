import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_channel.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_permission.dart';

/// The two pieces of the notification vocabulary.
///
/// Small, and worth pinning anyway: a channel id is a **stable key into the
/// user's own system settings**, and a permission state decides whether a button
/// in this app does anything at all.
void main() {
  group('the channels', () {
    test('are the two kinds of interruption, not one per reminder', () {
      // "7 days before" and "1 day before" are the same kind of message. Four
      // toggles for one decision makes turning reminders off a four-tap job;
      // which offsets fire is PayPaw's own setting, not Android's.
      expect(NotificationChannel.values, hasLength(2));
      expect(
        NotificationChannel.values.map((NotificationChannel c) => c.id),
        containsAll(<String>['bill_reminders', 'overdue_bills']),
      );
    });

    test('and overdue is separate from reminders on purpose', () {
      // A reminder is a courtesy someone might reasonably want none of. "This is
      // late" is the one message a bills app exists to send, and silencing the
      // first is not a request to silence the second.
      expect(
        NotificationChannel.billReminders.id,
        isNot(NotificationChannel.overdueBills.id),
      );
    });

    test('every id is unique', () {
      // Two channels sharing an id is one channel wearing the other's settings.
      final Set<String> ids = NotificationChannel.values
          .map((NotificationChannel c) => c.id)
          .toSet();

      expect(ids, hasLength(NotificationChannel.values.length));
    });

    test('and every one says what turning it off would silence', () {
      // The description is the line under the toggle in system settings. Blank,
      // the user is deciding without being told what the decision costs.
      for (final NotificationChannel channel in NotificationChannel.values) {
        expect(channel.name, isNotEmpty);
        expect(channel.description, isNotEmpty);
      }
    });

    test('the ids are the ones already shipped', () {
      // Pinned deliberately. Android keys a channel's settings — the user's own
      // choices about sound, importance and whether it is on — to this string. A
      // changed id is a new channel at defaults, silently discarding what they
      // chose, and the old one lingers in Settings doing nothing.
      expect(NotificationChannel.billReminders.id, 'bill_reminders');
      expect(NotificationChannel.overdueBills.id, 'overdue_bills');
    });
  });

  group('the permission states', () {
    test('granted allows posting; refused does not', () {
      expect(NotificationPermission.granted.allowsPosting, isTrue);
      expect(NotificationPermission.denied.allowsPosting, isFalse);
      expect(NotificationPermission.notRequested.allowsPosting, isFalse);
    });

    test('and so does a platform with no permission to grant', () {
      // Below Android 13 there is no runtime gate. Reporting that as "granted"
      // would be a claim the app is not in a position to make, but nothing is
      // blocking either.
      expect(NotificationPermission.notApplicable.allowsPosting, isTrue);
    });

    test('only "not asked" can be prompted', () {
      // The distinction the whole enum exists for. After a refusal Android
      // swallows the request silently, so a "Turn on reminders" button wired to
      // one is a button the user taps and taps.
      expect(NotificationPermission.notRequested.canPrompt, isTrue);
      expect(NotificationPermission.denied.canPrompt, isFalse);
      expect(NotificationPermission.granted.canPrompt, isFalse);
      expect(NotificationPermission.notApplicable.canPrompt, isFalse);
    });
  });

  group('reading the platform', () {
    test('enabled is granted, whether or not we ever asked', () {
      expect(
        NotificationPermission.resolve(enabled: true, hasAsked: false),
        NotificationPermission.granted,
      );
      expect(
        NotificationPermission.resolve(enabled: true, hasAsked: true),
        NotificationPermission.granted,
      );
    });

    test('not enabled and never asked is a prompt worth showing', () {
      expect(
        NotificationPermission.resolve(enabled: false, hasAsked: false),
        NotificationPermission.notRequested,
      );
    });

    test('not enabled after asking is a refusal, not a pending prompt', () {
      // The distinction Android will not make for us. It answers one question —
      // are notifications enabled — and false covers both, so the app has to
      // remember having asked or it offers a button the system ignores.
      expect(
        NotificationPermission.resolve(enabled: false, hasAsked: true),
        NotificationPermission.denied,
      );
    });
  });
}
