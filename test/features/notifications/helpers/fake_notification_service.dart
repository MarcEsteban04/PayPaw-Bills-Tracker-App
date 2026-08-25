import 'package:paypaw/features/notifications/domain/entities/bill_notice.dart';
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

  /// The bill a notification launched the app with, if any.
  String? launchedWithBillId;

  /// The most recent set handed to [replaceScheduledNotices].
  List<BillNotice> scheduled = const <BillNotice>[];

  /// Every set it has been given, in order. Lets a test assert that a write
  /// rebuilt the schedule *once*, rather than three times on the way.
  final List<List<BillNotice>> rebuilds = <List<BillNotice>>[];

  int initialiseCalls = 0;
  int requestCalls = 0;
  int settingsCalls = 0;

  @override
  Future<void> initialize({void Function(String billId)? onBillTapped}) async {
    initialiseCalls++;
    tapHandler = onBillTapped;
  }

  /// The handler the app registered. Calling it is how a test taps a
  /// notification.
  void Function(String billId)? tapHandler;

  @override
  Future<String?> billThatLaunchedTheApp() async => launchedWithBillId;

  @override
  Future<bool> refreshTimezone() async {
    timezoneReads++;

    if (failTimezoneRead) {
      throw StateError('the platform could not name the local zone');
    }

    // One move, then the phone has arrived. A fake that reported a change on
    // every resume would let a rebuild-on-every-resume bug pass.
    final bool moved = timezoneMoved;
    timezoneMoved = false;

    return moved;
  }

  /// How many times the app asked whether the device had changed zone.
  int timezoneReads = 0;

  /// Set by a test to say the phone has landed somewhere new. Cleared by the
  /// first [refreshTimezone] that reports it.
  bool timezoneMoved = false;

  /// Whether asking the platform for the local zone fails.
  bool failTimezoneRead = false;

  @override
  Future<void> replaceScheduledNotices(List<BillNotice> reminders) async {
    scheduled = reminders;
    rebuilds.add(reminders);
  }

  @override
  Future<Set<int>> scheduledNoticeIds() async =>
      scheduled.map((BillNotice r) => r.notificationId).toSet();

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
