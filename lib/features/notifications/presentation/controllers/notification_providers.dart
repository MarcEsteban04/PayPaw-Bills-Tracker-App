import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/storage_providers.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../data/repositories/supabase_reminder_preferences_repository.dart';
import '../../data/services/local_notification_service.dart';
import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/notification_permission.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/repositories/reminder_preferences_repository.dart';
import '../../domain/services/notification_service.dart';

/// The notification service.
///
/// Exposed as the abstract contract rather than the implementation, so a test
/// overrides it with a fake and nothing above this line learns that a method
/// channel is involved. Reading it in a widget test without an override reaches
/// a real plugin and hangs.
final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>(
      (Ref ref) => LocalNotificationService(
        FlutterLocalNotificationsPlugin(),
        ref.watch(sharedPreferencesProvider),
      ),
    );

/// The reminder preferences repository.
final Provider<ReminderPreferencesRepository>
reminderPreferencesRepositoryProvider = Provider<ReminderPreferencesRepository>(
  (Ref ref) =>
      SupabaseReminderPreferencesRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's reminder rules, or the defaults.
///
/// Keyed on the user, so signing in as somebody else on a shared phone does not
/// schedule reminders against the previous account's settings.
final FutureProvider<ReminderPreferences> reminderPreferencesProvider =
    FutureProvider<ReminderPreferences>((Ref ref) async {
      // Signed out, there is nothing to read and nothing to schedule. Returning
      // the defaults rather than throwing keeps the sync path free of a null
      // case it would only ever ignore.
      if (ref.watch(currentUserProvider).value == null) {
        return const ReminderPreferences();
      }

      return ref.watch(reminderPreferencesRepositoryProvider).fetch();
    });

/// Whether PayPaw may post notifications, and whether asking is worth doing.
///
/// A `FutureProvider` rather than a value, because the answer is a platform call
/// — and because it can change while the app is backgrounded. Anything that
/// turns on a reminder should `ref.invalidate` this after coming back from
/// system settings, or it will act on what was true before the user went there.
final FutureProvider<NotificationPermission> notificationPermissionProvider =
    FutureProvider<NotificationPermission>(
      (Ref ref) => ref.watch(notificationServiceProvider).permission(),
    );

/// Every per-bill reminder override, by bill id.
///
/// Separate from [reminderPreferencesProvider] so a screen editing one bill's
/// rules does not invalidate the defaults, and so the common case — a user with
/// no overrides at all — costs one query returning nothing rather than being
/// folded into every read of the defaults.
final FutureProvider<Map<String, BillReminderOverride>>
billReminderOverridesProvider =
    FutureProvider<Map<String, BillReminderOverride>>((Ref ref) async {
      if (ref.watch(currentUserProvider).value == null) {
        return const <String, BillReminderOverride>{};
      }

      return ref.watch(reminderPreferencesRepositoryProvider).fetchOverrides();
    });
