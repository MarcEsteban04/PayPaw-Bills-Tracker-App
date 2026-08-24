import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/storage_providers.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/prefs_onboarding_progress_store.dart';
import '../../data/repositories/supabase_account_setup_repository.dart';
import '../../domain/entities/account_setup.dart';
import '../../domain/entities/setup_options.dart';
import '../../domain/repositories/account_setup_repository.dart';
import '../../domain/repositories/onboarding_progress_store.dart';

/// Remembers which first-run screens have already been shown.
final Provider<OnboardingProgressStore> onboardingProgressStoreProvider =
    Provider<OnboardingProgressStore>(
      (Ref ref) =>
          PrefsOnboardingProgressStore(ref.watch(sharedPreferencesProvider)),
    );

/// Writes onboarding's answers.
final Provider<AccountSetupRepository> accountSetupRepositoryProvider =
    Provider<AccountSetupRepository>(
      (Ref ref) =>
          SupabaseAccountSetupRepository(ref.watch(supabaseClientProvider)),
    );

/// The form's starting values, guessed from the device.
///
/// A provider rather than a constructor default so a test can override the guess
/// instead of depending on where the machine running it happens to be — the exact
/// mistake that makes a suite pass in Manila and fail in CI.
final Provider<AccountSetup> deviceSetupDefaultsProvider =
    Provider<AccountSetup>((Ref ref) {
      final PlatformDispatcher dispatcher = PlatformDispatcher.instance;

      final String? currency = SetupOptions.currencyForCountry(
        dispatcher.locale.countryCode,
      );
      final String? timeZone = SetupOptions.timeZoneForOffset(
        DateTime.now().timeZoneOffset,
      );

      // Falling through to AccountSetup's own defaults, which are the column
      // defaults, so a guess we are not confident about costs nothing.
      return AccountSetup(
        currency: currency ?? AccountSetup.defaultCurrency,
        timeZone: timeZone ?? AccountSetup.defaultTimeZone,
      );
    });
