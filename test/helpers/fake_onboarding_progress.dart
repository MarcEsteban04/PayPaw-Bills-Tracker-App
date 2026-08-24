import 'package:paypaw/features/onboarding/domain/repositories/onboarding_progress_store.dart';

/// First-run state, set by hand and recorded when written.
///
/// Shared rather than redefined per test file: four suites need it, and the
/// interesting part is always which of the two flags is set. The defaults
/// describe a **returning, fully set-up user**, so a test that cares about first
/// run has to say so explicitly — which keeps the first-run cases visible
/// instead of implied by an empty map.
class FakeOnboardingProgress implements OnboardingProgressStore {
  FakeOnboardingProgress({this.hasSeenWelcome = true, Set<String>? onboarded})
    : onboarded = onboarded ?? <String>{};

  @override
  bool hasSeenWelcome;

  /// Ids that have finished onboarding. A set rather than a bool, because the
  /// real store keys this per account.
  final Set<String> onboarded;

  @override
  bool hasCompletedOnboarding(String userId) => onboarded.contains(userId);

  @override
  Future<void> markOnboardingCompleted(String userId) async =>
      onboarded.add(userId);

  @override
  Future<void> markWelcomeSeen() async => hasSeenWelcome = true;
}
