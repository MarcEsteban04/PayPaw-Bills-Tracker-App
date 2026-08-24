import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/notification_permission.dart';
import '../../domain/services/notification_service.dart';
import '../controllers/notification_providers.dart';

/// Asks for notification permission, at the point it starts to matter.
///
/// ## Why here and not on first launch
///
/// A permission dialog before the user has seen what the app is for is the one
/// most reliably refused — and on Android 13 a refusal is final: the system
/// swallows every later request without showing anything. So the ask waits until
/// there is something to ask *about*, and says what it is for.
///
/// ## It appears only when it can change something
///
/// Absent when permission is granted, when the platform has none to grant, and
/// when the user has no bills to be reminded of. A card offering to turn on
/// reminders for an empty list is a chore invented for someone who has not
/// started yet.
///
/// After a refusal it does not disappear — it changes. The prompt becomes a
/// route into system settings, because that is the only way back and a button
/// still wired to the request would be one the user taps and taps.
class ReminderPermissionCard extends ConsumerWidget {
  const ReminderPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationPermission? permission = ref
        .watch(notificationPermissionProvider)
        .value;

    // Null while the platform is being asked, which is a moment. Nothing is
    // drawn in the meantime rather than a placeholder: a card that appears a
    // beat after the screen settles, offering something the user did not ask
    // for, reads as an advert.
    if (permission == null || permission.allowsPosting) {
      return const SizedBox.shrink();
    }

    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool canAsk = permission.canPrompt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.dueSoonTint,
        borderRadius: AppRadii.panel,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.notifications_active_outlined,
            size: 20,
            color: colors.dueSoonText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Reminders are off',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.dueSoonText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  canAsk
                      // What it will do, not what it needs. "PayPaw requires
                      // the notification permission" describes the app's
                      // problem; this describes the user's.
                      ? 'Let PayPaw tell you before a bill is due.'
                      // After a refusal the honest thing is to say where the
                      // switch is, rather than ask again and be ignored.
                      : 'Turn notifications on in Settings to be told before a '
                            'bill is due.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.dueSoonText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _act(ref, canAsk: canAsk),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.dueSoonText,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(canAsk ? 'Turn on reminders' : 'Open settings'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _act(WidgetRef ref, {required bool canAsk}) async {
    final NotificationService service = ref.read(notificationServiceProvider);

    if (canAsk) {
      await service.requestPermission();
    } else {
      await service.openSettings();
    }

    // Re-read afterwards. The answer changed if the user granted it, and after a
    // trip to system settings it may have changed without this app being told —
    // the provider caches, so nothing else would notice.
    ref.invalidate(notificationPermissionProvider);
  }
}
