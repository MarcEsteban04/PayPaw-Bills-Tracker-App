import 'package:paypaw/features/notifications/domain/entities/notification_permission.dart';
import 'package:paypaw/features/notifications/domain/services/notification_service.dart';

/// An in-memory [NotificationService].
///
/// The real one is a method channel, which in a widget test either hangs or
/// needs a hand-written mock handler for every call. This lets a screen be
/// tested against "permission refused" without any of that.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.permissionState = NotificationPermission.notRequested,
    this.grantOnRequest = true,
    this.enabled = true,
  });

  NotificationPermission permissionState;

  /// What the user does when asked.
  bool grantOnRequest;

  /// Whether notifications would actually appear — the system-settings switch,
  /// which is a different question from the permission.
  bool enabled;

  int initialiseCalls = 0;
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<void> initialize() async => initialiseCalls++;

  @override
  Future<NotificationPermission> permission() async => permissionState;

  @override
  Future<NotificationPermission> requestPermission() async {
    requestCalls++;

    // Once refused, Android will not show the dialog again — a second request
    // returns false without asking anyone. The fake reproduces that, because a
    // screen that assumes otherwise has a button that does nothing.
    if (permissionState == NotificationPermission.denied) {
      return permissionState;
    }

    permissionState = grantOnRequest
        ? NotificationPermission.granted
        : NotificationPermission.denied;

    return permissionState;
  }

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<void> openSettings() async => settingsCalls++;
}
