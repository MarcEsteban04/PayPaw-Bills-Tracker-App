import '../entities/bill_notice.dart';
import '../entities/notification_permission.dart';

/// The device's notification machinery, as PayPaw needs it.
///
/// An interface rather than the plugin directly, for the reason every repository
/// here is one: nothing above this line should know that
/// `flutter_local_notifications` exists, and a test needs something it can
/// substitute. The plugin is a method channel — unusable in a widget test
/// without a mock handler, and unpleasant with one.
///
/// Every method is safe to call more than once.
abstract interface class NotificationService {
  /// Loads the timezone database, initialises the plugin, and registers the
  /// channels.
  ///
  /// **The timezone half is not optional.** `package:timezone` defaults its
  /// local zone to UTC, and a reminder scheduled for "9am on the due date" in
  /// UTC arrives at 5pm in Manila. The device's own IANA zone is read and set
  /// here, which is also what makes the schedule survive DST and travel — the
  /// stored zone is a place, not an offset.
  ///
  /// Called from `main()` before the first frame. It does **not** ask for
  /// permission: a permission dialog on first launch, before the user has seen
  /// what the app is for, is the one most reliably refused.
  ///
  /// [onBillTapped] receives the id of the bill whose reminder was tapped. It is
  /// wired here rather than exposed as a stream because a notification can
  /// launch the app from cold, and the handler has to be in place before the
  /// plugin reports that.
  Future<void> initialize({void Function(String billId)? onBillTapped});

  /// Re-reads the device's timezone. True if it moved.
  ///
  /// [initialize] reads it once, and once is not enough: a phone that crosses a
  /// border — or simply has "set automatically" turned on and lands somewhere —
  /// changes zone under a process that is still running, and every reminder on
  /// it was placed against the old one. A user who flies from Manila to London
  /// would be warned about tomorrow's rent at one in the morning.
  ///
  /// The caller is expected to rebuild the schedule when this returns true;
  /// nothing here reschedules anything. Returns false when the zone is
  /// unchanged, which is the overwhelmingly common case and the reason this
  /// answers a question rather than doing the work unconditionally.
  Future<bool> refreshTimezone();

  /// The bill whose reminder started the app, if one did.
  ///
  /// A tap on a notification while the app is dead does not reach
  /// `onBillTapped` — the process did not exist to receive it. The plugin holds
  /// the launch details instead, and this is the only way to find out. Returns
  /// null on a normal launch, and answers once: it reflects how the process
  /// started, not what has been tapped since.
  Future<String?> billThatLaunchedTheApp();

  /// Replaces every scheduled reminder with [reminders].
  ///
  /// ## Replace, never merge
  ///
  /// The caller hands over the complete set that should exist, and this cancels
  /// everything first. Reconciling instead — work out which are new, which
  /// changed, which should go — needs an accurate record of what was scheduled,
  /// and the only such record lives in the platform, survives reinstalls
  /// unevenly and is rebuilt from scratch after a reboot.
  ///
  /// The failure that avoids is the one that matters: a reminder left scheduled
  /// for a bill that was paid, deleted, or moved. It fires anyway, it is right
  /// about nothing, and the user cannot make it stop.
  Future<void> replaceScheduledNotices(List<BillNotice> reminders);

  /// Everything currently scheduled, by notification id.
  ///
  /// For verifying on a device what the app believes it has arranged — there is
  /// otherwise no way to see a schedule that will not fire for days.
  Future<Set<int>> scheduledNoticeIds();

  /// Whether PayPaw may post notifications, and whether asking is worth doing.
  Future<NotificationPermission> permission();

  /// Asks the user, once.
  ///
  /// Returns the resulting state. A second call after a refusal returns [denied]
  /// without showing anything — Android will not re-prompt — so a caller should
  /// check [NotificationPermission.canPrompt] first and send the user to system
  /// settings otherwise.
  Future<NotificationPermission> requestPermission();

  /// Whether notifications from this app would actually appear.
  ///
  /// Separate from [permission], and both can disagree: a user who granted the
  /// permission and later switched the app off in system settings is `granted`
  /// and *not* enabled. Anything that promises the user a reminder needs this
  /// one, not the other.
  Future<bool> areEnabled();

  /// Opens this app's page in the system notification settings.
  ///
  /// The only way back from a refusal, since the permission dialog will not
  /// show again.
  Future<void> openSettings();
}
