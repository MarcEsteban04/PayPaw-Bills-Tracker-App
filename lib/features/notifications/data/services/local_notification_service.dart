import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/notification_channel.dart';
import '../../domain/entities/notification_permission.dart';
import '../../domain/services/notification_service.dart';

/// [NotificationService] over `flutter_local_notifications`.
///
/// The only file in the app that imports the plugin, the timezone packages, or
/// knows what an Android channel is.
///
/// ## Android only, and it says so rather than pretending
///
/// PayPaw ships for Android. The plugin's iOS and macOS settings are absent
/// because there is nothing to configure them against, and adding them
/// speculatively would be untested code claiming platform support the project
/// does not have. On any other platform every method here degrades to a no-op
/// rather than throwing — a desktop test run should not die on a method channel.
class LocalNotificationService implements NotificationService {
  /// Positional, like every repository here: a named parameter cannot start
  /// with an underscore, so `this._field` is the only form that keeps the fields
  /// private without writing the assignments out.
  LocalNotificationService(this._plugin, this._preferences);

  final FlutterLocalNotificationsPlugin _plugin;
  final SharedPreferences _preferences;

  /// Whether the permission dialog has ever been shown.
  ///
  /// Remembered here because the platform will not say. Android reports whether
  /// notifications are *enabled*, which is false both before the first prompt
  /// and after a refusal — and those two need opposite handling, since only the
  /// first can still be prompted. See [NotificationPermission].
  static const String _askedKey = 'notifications.permission_requested';

  bool _initialised = false;

  @override
  Future<void> initialize() async {
    if (_initialised) {
      return;
    }
    _initialised = true;

    await _configureTimezone();

    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      return;
    }

    await android.initialize(
      // The launcher icon, as a small icon. Android tints and masks it to a
      // silhouette, so anything with colour or detail arrives as a grey blob —
      // a dedicated monochrome drawable is the eventual right answer and is
      // worth doing when there is a designed one to use.
      settings: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      // No `onDidReceiveNotificationResponse`. Nothing posts a notification yet,
      // so nothing can be tapped; the handler arrives in Sprint 40 alongside the
      // first reminder and the payload it carries.
    );

    for (final NotificationChannel channel in NotificationChannel.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          channel.id,
          channel.name,
          description: channel.description,
          // High, not max. High posts a heads-up banner, which is right for
          // "your rent is due tomorrow". Max is reserved for things that should
          // interrupt a phone call, and a bill is not one.
          importance: Importance.high,
        ),
      );
    }
  }

  @override
  Future<NotificationPermission> permission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      return NotificationPermission.notApplicable;
    }

    return NotificationPermission.resolve(
      enabled: await android.areNotificationsEnabled() ?? false,
      hasAsked: _preferences.getBool(_askedKey) ?? false,
    );
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _android;
    if (android == null) {
      return NotificationPermission.notApplicable;
    }

    // Recorded before the call, not after. If the process is killed while the
    // dialog is up — which the system may do — the user has still seen it, and
    // an app that forgets would show a "Turn on reminders" button that silently
    // does nothing forever after.
    await _preferences.setBool(_askedKey, true);

    final bool granted =
        await android.requestNotificationsPermission() ?? false;

    return granted
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<bool> areEnabled() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<void> openSettings() async {
    await _android?.openAppNotificationSettings();
  }

  /// Points `package:timezone` at the device's own zone.
  ///
  /// Its default is UTC, which for a Philippine user is eight hours wrong in the
  /// direction that matters: a reminder set for 9am would arrive at 5pm, after
  /// the working day it was meant to precede.
  ///
  /// A zone *name* rather than an offset, because an offset cannot survive DST
  /// or a flight. `initializeTimeZones` loads the full database so a user who
  /// travels gets the rules of wherever they now are.
  Future<void> _configureTimezone() async {
    tz_data.initializeTimeZones();

    try {
      final TimezoneInfo zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } on Object catch (error) {
      // A zone the database does not know, or a platform that cannot say. UTC
      // is wrong but usable, and it is the package's default — so the app runs
      // and reminders are hours out, rather than the app failing to start over
      // a clock.
      //
      // Deliberately not rethrown: this runs before the first frame, and there
      // is no screen yet on which to report anything.
      debugPrint(
        'PayPaw: could not resolve the local timezone ($error). '
        'Falling back to UTC; scheduled reminders may be hours out.',
      );
    }
  }

  /// The Android implementation, or null where there is not one.
  ///
  /// **`resolvePlatformSpecificImplementation` throws rather than returning
  /// null** when no platform implementation has been registered — a
  /// `LateInitializationError` from inside the platform interface, which is not
  /// a failure any caller here could act on. Every method in this class is
  /// written against null, so it is turned into null once, here.
  ///
  /// That is the state of a host test run and of any platform the plugin does
  /// not cover. It is not a state to report: nothing is broken, there is simply
  /// no notification machinery to talk to.
  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } on Object {
      return null;
    }
  }
}
