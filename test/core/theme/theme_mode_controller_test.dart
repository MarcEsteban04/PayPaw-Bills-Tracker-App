import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/core/providers/storage_providers.dart';
import 'package:paypaw/core/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The theme preference has to survive a restart, so these tests care about what
/// reaches storage as much as what reaches the UI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> makeContainer({
    Map<String, Object> stored = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(stored);
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    return (container, preferences);
  }

  test('follows the device when nothing has been chosen', () async {
    final (ProviderContainer container, _) = await makeContainer();

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('restores a previously chosen mode', () async {
    final (ProviderContainer container, _) = await makeContainer(
      stored: <String, Object>{ThemeModeController.storageKey: 'dark'},
    );

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('falls back to system for a value it does not recognise', () async {
    // A value written by a future build, or corrupted storage. Falling back
    // beats throwing on launch.
    final (ProviderContainer container, _) = await makeContainer(
      stored: <String, Object>{ThemeModeController.storageKey: 'sepia'},
    );

    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test('remembers a change', () async {
    final (ProviderContainer container, SharedPreferences preferences) =
        await makeContainer();

    await container
        .read(themeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(preferences.getString(ThemeModeController.storageKey), 'dark');
  });

  test('a stored choice is read back by a fresh container', () async {
    final (ProviderContainer first, SharedPreferences preferences) =
        await makeContainer();
    await first.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);

    // Same storage, new container — this is what a relaunch looks like.
    final ProviderContainer second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(second.dispose);

    expect(second.read(themeModeProvider), ThemeMode.light);
  });
}
