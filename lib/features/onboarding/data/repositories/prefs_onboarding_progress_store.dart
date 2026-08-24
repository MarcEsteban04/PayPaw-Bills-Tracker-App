import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/onboarding_progress_store.dart';

/// [OnboardingProgressStore] backed by `SharedPreferences`.
///
/// Reads are synchronous, which is the point: the router's guard has to decide
/// where to send the user *before* the first frame, and an async read there
/// means showing something and then replacing it.
class PrefsOnboardingProgressStore implements OnboardingProgressStore {
  const PrefsOnboardingProgressStore(this._preferences);

  static const String _welcomeSeenKey = 'onboarding.welcome_seen';

  /// Suffixed with the user id, so two accounts on one phone are asked
  /// separately.
  static const String _onboardingCompletedPrefix = 'onboarding.completed.';

  final SharedPreferences _preferences;

  @override
  bool get hasSeenWelcome => _preferences.getBool(_welcomeSeenKey) ?? false;

  @override
  Future<void> markWelcomeSeen() => _preferences.setBool(_welcomeSeenKey, true);

  @override
  bool hasCompletedOnboarding(String userId) =>
      _preferences.getBool(_keyFor(userId)) ?? false;

  @override
  Future<void> markOnboardingCompleted(String userId) =>
      _preferences.setBool(_keyFor(userId), true);

  static String _keyFor(String userId) => '$_onboardingCompletedPrefix$userId';
}
