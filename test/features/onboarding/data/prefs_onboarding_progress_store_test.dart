import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/onboarding/data/repositories/prefs_onboarding_progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real store, tested directly.
///
/// Every other suite replaces it with a fake, which is right — they are about
/// what the flags *mean*. Nothing would then cover whether the flags are
/// actually stored, and "onboarding runs again on every launch" is a bug nobody
/// notices in review.
void main() {
  Future<PrefsOnboardingProgressStore> store([
    Map<String, Object> initial = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return PrefsOnboardingProgressStore(await SharedPreferences.getInstance());
  }

  group('the welcome flag', () {
    test('starts unset on a fresh install', () async {
      expect((await store()).hasSeenWelcome, isFalse);
    });

    test('is remembered once marked', () async {
      final PrefsOnboardingProgressStore progress = await store();

      await progress.markWelcomeSeen();

      expect(progress.hasSeenWelcome, isTrue);
    });

    test('survives a new store over the same preferences', () async {
      // Standing in for a relaunch: the flag has to come back from disk, not
      // from the instance that wrote it.
      final PrefsOnboardingProgressStore first = await store();
      await first.markWelcomeSeen();

      final PrefsOnboardingProgressStore second = PrefsOnboardingProgressStore(
        await SharedPreferences.getInstance(),
      );

      expect(second.hasSeenWelcome, isTrue);
    });
  });

  group('the onboarding flag', () {
    test('is per account, not per install', () async {
      // A shared phone: the second account gets asked its own preferences rather
      // than inheriting the first account's currency and time zone.
      final PrefsOnboardingProgressStore progress = await store();

      await progress.markOnboardingCompleted('user-1');

      expect(progress.hasCompletedOnboarding('user-1'), isTrue);
      expect(progress.hasCompletedOnboarding('user-2'), isFalse);
    });

    test('does not leak between accounts in either direction', () async {
      final PrefsOnboardingProgressStore progress = await store();

      await progress.markOnboardingCompleted('user-2');

      expect(progress.hasCompletedOnboarding('user-1'), isFalse);
      expect(progress.hasCompletedOnboarding('user-2'), isTrue);
    });

    test('is independent of the welcome flag', () async {
      // Having seen the pitch says nothing about having configured an account,
      // and the guard treats them as separate questions.
      final PrefsOnboardingProgressStore progress = await store();

      await progress.markWelcomeSeen();

      expect(progress.hasCompletedOnboarding('user-1'), isFalse);
    });
  });
}
