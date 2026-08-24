import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/storage_providers.dart';
import '../../data/services/local_notification_service.dart';
import '../../domain/entities/notification_permission.dart';
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
