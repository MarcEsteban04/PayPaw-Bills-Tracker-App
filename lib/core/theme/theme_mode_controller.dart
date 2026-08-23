import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/storage_providers.dart';

/// The user's light/dark preference, persisted across launches.
///
/// Lives in `core/theme` rather than in a feature because the root widget reads
/// it before any feature exists, and no feature owns it. When a settings feature
/// arrives it should *use* this rather than re-implement it.
///
/// Defaults to [ThemeMode.system]: following the device is the least surprising
/// behaviour, and it means a user who has set their phone to dark at sunset does
/// not have to set PayPaw separately.
class ThemeModeController extends Notifier<ThemeMode> {
  /// Preference key. Namespaced so settings added later cannot collide with it.
  static const String storageKey = 'settings.themeMode';

  @override
  ThemeMode build() {
    final SharedPreferences preferences = ref.watch(sharedPreferencesProvider);
    return _decode(preferences.getString(storageKey));
  }

  /// Changes the theme and remembers the choice.
  ///
  /// State updates first so the UI turns over immediately; the write follows.
  /// If the write fails the app still looks right this session and falls back to
  /// the device setting on the next launch — the better failure of the two.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == state) {
      return;
    }

    state = mode;
    await ref.read(sharedPreferencesProvider).setString(storageKey, mode.name);
  }

  /// Anything unrecognised — a missing key, or a value written by an older
  /// build — falls back to following the device.
  static ThemeMode _decode(String? stored) {
    return ThemeMode.values.firstWhere(
      (ThemeMode mode) => mode.name == stored,
      orElse: () => ThemeMode.system,
    );
  }
}

/// The active theme mode.
final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
