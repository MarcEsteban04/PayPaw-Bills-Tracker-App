import '../entities/notification_permission.dart';

/// The device's notification machinery, as PayPaw needs it.
///
/// An interface rather than the plugin directly, for the reason every repository
/// here is one: nothing above this line should know that
/// `flutter_local_notifications` exists, and a test needs something it can
/// substitute. The plugin is a method channel — unusable in a widget test
/// without a mock handler, and unpleasant with one.
///
/// ## Scheduling is not here yet
///
/// Sprint 39 is the infrastructure: the plugin is initialised, the timezone
/// database is loaded and pointed at the device's own zone, the channels exist,
/// and the app can find out whether it is allowed to post. **Nothing posts or
/// schedules anything** — those methods arrive in Sprint 40 with the reminders
/// that need them, rather than sitting here untested and unexercised.
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
  Future<void> initialize();

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
