import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/notifications/data/services/local_notification_service.dart';
import 'package:paypaw/features/notifications/domain/entities/notification_permission.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// The service, where the plugin has no platform implementation registered.
///
/// Which is what a host test run is, and what any platform the plugin does not
/// cover would be. The Android branch needs a device and is verified there; what
/// these pin down is the **degradation** — every method answering honestly
/// instead of throwing.
///
/// That is not hypothetical robustness. The plugin's resolver *throws* a
/// LateInitializationError rather than returning null when nothing is
/// registered, so before these tests every method here died on the first call
/// off-device.
///
/// The decision the service actually makes — which permission state a bool from
/// the platform describes — lives in `NotificationPermission.resolve` and is
/// tested next door, without a channel in sight.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalNotificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    service = LocalNotificationService(
      FlutterLocalNotificationsPlugin(),
      await SharedPreferences.getInstance(),
    );
  });

  group('initialising', () {
    test('loads the timezone database even where there is no plugin', () async {
      // The half that is pure Dart, and the half that matters most: every
      // scheduled reminder is computed against this database, and a schedule
      // written before it loads is written in UTC.
      await service.initialize();

      expect(tz.timeZoneDatabase.isInitialized, isTrue);
      // A real zone resolves, which is what a reminder is scheduled against.
      expect(tz.getLocation('Asia/Manila').name, 'Asia/Manila');
    });

    test('and is safe to call twice', () async {
      // `main()` calls it once, but a hot restart or a second container would
      // reach it again, and re-registering channels is not free.
      await service.initialize();
      await service.initialize();

      expect(tz.timeZoneDatabase.isInitialized, isTrue);
    });
  });

  group('re-reading the timezone', () {
    test('reports no change on the first ask', () async {
      // There is nothing to compare against yet, and nothing has been scheduled
      // that could be wrong. Reporting a move here would have every launch
      // cancelling and re-laying the whole schedule for no reason.
      expect(await service.refreshTimezone(), isFalse);
    });

    test('and none on a second, since the device has not moved', () async {
      // The overwhelmingly common case: this runs on every resume, and a resume
      // is frequent. It answers a question rather than doing the work, so that
      // "nothing happened" costs nothing.
      await service.initialize();

      expect(await service.refreshTimezone(), isFalse);
      expect(await service.refreshTimezone(), isFalse);
    });

    test('it leaves the database loaded and a zone set', () async {
      // Off-device the platform cannot name a zone, so this falls back to UTC —
      // which is the point of the test: the fallback is a working state, not a
      // half-initialised one that the next scheduled reminder would trip over.
      await service.refreshTimezone();

      expect(tz.timeZoneDatabase.isInitialized, isTrue);
      expect(tz.local.name, isNotEmpty);
    });
  });

  group('with no platform implementation', () {
    test('reports that there is no permission to grant', () async {
      // Not `denied`. Nothing has refused anything — there is simply no runtime
      // gate here, and saying "denied" would send a caller to a settings screen
      // that has nothing to change.
      expect(await service.permission(), NotificationPermission.notApplicable);
    });

    test('asking changes nothing and says so', () async {
      expect(
        await service.requestPermission(),
        NotificationPermission.notApplicable,
      );
    });

    test('and nothing would be delivered', () async {
      // `areEnabled` is the honest answer to "would a notification appear", and
      // here it would not.
      expect(await service.areEnabled(), isFalse);
    });

    test('opening settings is a no-op rather than a crash', () async {
      await expectLater(service.openSettings(), completes);
    });
  });
}
