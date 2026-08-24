/// Remembers what the user has already been through, on this device.
///
/// Two separate questions, deliberately, because they have different scopes:
///
/// - **Welcome** is per *install*. It runs before there is an account to attach
///   it to, and someone who signs out should not be pitched the app again.
/// - **Onboarding** is per *account*, keyed by user id. Signing in as a second
///   account on a shared phone should collect that account's preferences, not
///   inherit the first one's.
///
/// Local storage rather than a column: this is navigation state, and a screen
/// that has to wait for the network to decide whether to show itself is a screen
/// that flickers. The preferences it *collects* are persisted server-side; only
/// the "have we asked yet" flag is local.
abstract interface class OnboardingProgressStore {
  bool get hasSeenWelcome;

  Future<void> markWelcomeSeen();

  bool hasCompletedOnboarding(String userId);

  Future<void> markOnboardingCompleted(String userId);
}
