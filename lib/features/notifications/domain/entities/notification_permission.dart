/// Whether PayPaw may post notifications.
///
/// ## Three states, not a bool
///
/// A bool cannot tell "not asked yet" from "asked and refused", and those two
/// need opposite handling: the first is a prompt worth showing, the second is a
/// prompt the system will silently swallow. On Android 13 a second
/// `requestPermission` after a refusal returns false without showing anything,
/// so an app that treats the two the same has a button that appears to do
/// nothing.
///
/// [notApplicable] is the fourth, and it is not a failure. Below Android 13
/// there is no runtime permission at all — notifications are allowed unless the
/// user turns them off in Settings — and reporting that as "granted" would be a
/// claim this app is not in a position to make.
enum NotificationPermission {
  /// Allowed to post.
  granted,

  /// Refused. Asking again does nothing; the way back is system settings.
  denied,

  /// Never asked. The only state in which prompting is worth doing.
  notRequested,

  /// This platform has no runtime permission to grant.
  notApplicable;

  /// Works out which state the platform is describing.
  ///
  /// Android answers one question — are notifications enabled — and that single
  /// bool covers two situations that need opposite handling. Not enabled and
  /// never asked is a prompt worth showing; not enabled and already asked is a
  /// prompt the system will swallow. Only the app knows which, because only the
  /// app remembers having asked.
  ///
  /// A pure function rather than a branch inside the service, so the decision
  /// can be tested without a method channel — the platform call is trivial and
  /// this is where the thinking is.
  static NotificationPermission resolve({
    required bool enabled,
    required bool hasAsked,
  }) {
    if (enabled) {
      return granted;
    }

    return hasAsked ? denied : notRequested;
  }

  /// Whether a notification stands a chance of arriving.
  ///
  /// [notApplicable] counts: there is no permission gate, so nothing is blocking
  /// on this side. The user may still have switched the app off in Settings, and
  /// that is a different question — see `NotificationService.areEnabled`.
  bool get allowsPosting => this == granted || this == notApplicable;

  /// Whether asking would put a dialog on screen.
  ///
  /// False after a refusal, which is the case that matters: a "Turn on
  /// reminders" button wired to a request that cannot show is a button that does
  /// nothing, and the user is left tapping it.
  bool get canPrompt => this == notRequested;
}
