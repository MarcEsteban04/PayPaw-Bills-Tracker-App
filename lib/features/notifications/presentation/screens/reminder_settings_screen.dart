import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/bill_notice.dart';
import '../../domain/entities/notification_permission.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/entities/reminder_time.dart';
import '../controllers/notification_providers.dart';
import '../controllers/reminder_settings_controller.dart';
import '../widgets/reminder_day_selector.dart';
import '../widgets/reminder_permission_card.dart';
import '../widgets/reminder_time_field.dart';

/// The reminder defaults, at last editable.
///
/// Onboarding has said "you can change this any time in Profile" since Sprint
/// 11B, and until now that was not true: the preferences were collected once and
/// then only ever read. This is the screen that promise was about.
///
/// ## Every control saves itself
///
/// There is no Save button. Each control here is one complete decision — a
/// switch, a set of toggles, a time — and a form that collects four of those and
/// then asks for confirmation is a form that can be abandoned halfway, leaving
/// the user unsure which half took.
///
/// The trade is that a failed write has to be *shown*, because there is no
/// button left to retry. It arrives as a toast, and the control springs back to
/// what the database still says.
class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReminderPreferences> preferences = ref.watch(
      reminderPreferencesProvider,
    );

    // Failures from every control on the screen, in one place. The controls
    // themselves are stateless and re-read from the provider, so a rejected
    // write leaves them showing the truth — but silently, which on a screen with
    // no Save button reads as the tap not registering.
    ref.listen<ReminderSettingsState>(reminderSettingsControllerProvider, (
      ReminderSettingsState? previous,
      ReminderSettingsState next,
    ) {
      if (next.errorMessage case final String message
          when message != previous?.errorMessage) {
        showAppToast(context, message: message, tone: AppToastTone.error);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        child: AppContentWidth(
          child: switch (preferences) {
            AsyncValue<ReminderPreferences>(
              value: final ReminderPreferences value?,
            ) =>
              _Settings(preferences: value),
            AsyncError<ReminderPreferences>(error: final Object error) =>
              AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(reminderPreferencesProvider),
              ),
            _ => const Center(child: AppLoadingIndicator()),
          },
        ),
      ),
    );
  }
}

class _Settings extends ConsumerWidget {
  const _Settings({required this.preferences});

  final ReminderPreferences preferences;

  /// The offsets offered.
  ///
  /// The same four onboarding offers, which is the point — a user who chose
  /// there and comes here should find their answer among the choices rather than
  /// a different set that silently drops it. The column allows 0 to 60; these
  /// are the ones worth a tap.
  static const List<int> _choices = <int>[7, 3, 1, 0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isSaving = ref
        .watch(reminderSettingsControllerProvider)
        .isSaving;
    final NotificationPermission? permission = ref
        .watch(notificationPermissionProvider)
        .value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        AppSpacing.bottomNavClearance,
      ),
      children: <Widget>[
        // Above the settings, not below them. A screen of switches that cannot
        // produce a notification is worth saying so at the top, before the user
        // spends time arranging what will never arrive.
        if (permission != null && !permission.allowsPosting) ...<Widget>[
          const ReminderPermissionCard(),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: preferences.isEnabled,
          onChanged: isSaving
              ? null
              : (bool value) =>
                    _save(ref, preferences.copyWith(isEnabled: value)),
          title: Text('Remind me about bills', style: textTheme.titleMedium),
          subtitle: Text(
            // Says what the switch actually covers. It reads as "reminders" but
            // it silences overdue alerts too, and a user who turns it off and
            // then misses a late bill deserves to have been told.
            'Turns off reminders and overdue alerts together.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text(
          'Remind me',
          style: textTheme.labelLarge?.copyWith(
            color: preferences.isEnabled
                ? colors.textPrimary
                : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ReminderDaySelector(
          choices: _choices,
          selected: preferences.orderedOffsets,
          // Left visible rather than hidden when reminders are off, so turning
          // the switch back on does not reveal a section that was never seen.
          enabled: preferences.isEnabled && !isSaving,
          onToggle: (int day) => _toggleDay(ref, day),
        ),

        const SizedBox(height: AppSpacing.xl),
        ReminderTimeField(
          time: preferences.timeOfDay,
          enabled: preferences.isEnabled && !isSaving,
          onChanged: (ReminderTime time) =>
              _save(ref, preferences.copyWith(timeOfDay: time)),
        ),

        const SizedBox(height: AppSpacing.sectionGap),
        const _OverdueNote(),
      ],
    );
  }

  /// Turns one offset on or off.
  ///
  /// Refuses to remove the last one. The column's check demands at least one
  /// offset, and an empty set would mean reminders that are switched on and
  /// never arrive — which is worse than either honest state. Turning them *all*
  /// off is what the switch above is for, and it says so.
  void _toggleDay(WidgetRef ref, int day) {
    final List<int> next = List<int>.of(preferences.orderedOffsets);

    if (next.contains(day)) {
      if (next.length == 1) {
        return;
      }
      next.remove(day);
    } else {
      if (next.length >= ReminderPreferences.maxOffsets) {
        return;
      }
      next.add(day);
    }

    _save(ref, preferences.copyWith(daysBefore: next));
  }

  void _save(WidgetRef ref, ReminderPreferences next) {
    ref.read(reminderSettingsControllerProvider.notifier).saveDefaults(next);
  }
}

/// What happens after a bill is late, stated rather than configurable.
///
/// It is not a setting, and a screen that lists every other reminder rule while
/// staying silent about this one invites the reader to assume it is off.
class _OverdueNote extends StatelessWidget {
  const _OverdueNote();

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String days = BillNoticeSchedule.overdueDays.join(', ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.panel,
        border: colors.surfaceBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colors.overdueText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'If a bill goes unpaid',
                  style: textTheme.titleSmall?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'PayPaw will say so after $days days, and then stop. It is '
                  'not something to arrange: being told a bill is late is the '
                  'one message worth keeping.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
