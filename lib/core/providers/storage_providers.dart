import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Non-sensitive local settings: theme mode, onboarding seen, last opened tab.
///
/// [SharedPreferences] needs an `await` to construct, which a synchronous
/// `Provider` cannot do. It is resolved once in `main()` and injected here with
/// `overrideWithValue`, so every read afterwards is synchronous. Reading this
/// provider without that override is a programming error, and throws.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>(
      (Ref ref) => throw UnimplementedError(
        'sharedPreferencesProvider was read before main() overrode it. '
        'Add the override to ProviderScope.',
      ),
    );

/// Sensitive local values: the app-lock PIN and any cached credential.
///
/// Backed by the Android Keystore. Never put a bill, amount, or payee here —
/// secure storage is slow and size-limited; it is for secrets only.
///
/// Default options are used deliberately: as of v11 the plugin already applies
/// AES-GCM encryption with RSA-OAEP key wrapping, so there is nothing to
/// harden by hand.
final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((Ref ref) => const FlutterSecureStorage());
