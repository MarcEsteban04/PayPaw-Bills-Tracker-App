import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_dropdown_field.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../notifications/domain/entities/reminder_time.dart';
import '../../domain/entities/account_setup.dart';
import '../../domain/entities/setup_options.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_step_header.dart';
import '../widgets/reminder_day_selector.dart';

/// Two steps of setup, run once per account, immediately after sign-up.
///
/// ## Why this is not a feature tour
///
/// A three-slide carousel explaining that a bills app tracks bills is the
/// most-skipped screen in mobile software, and skipping it is the correct
/// response — it costs the user time and leaves nothing behind. These two steps
/// write to `profiles.currency`, `profiles.time_zone` and
/// `reminder_preferences`, all of which the app needs and cannot guess reliably.
/// The user finishes with a configured account rather than a vague sense of what
/// the app does.
///
/// ## Why after sign-up and not before
///
/// Every write here is protected by a policy comparing against `auth.uid()`.
/// Collecting the answers first would mean holding them somewhere until a
/// session exists, and losing them if sign-up were abandoned.
///
/// ## Why skipping still writes
///
/// See [OnboardingController.skip]. A skipped account and a completed one that
/// changed nothing end up identical, so no later feature has to handle a third
/// case.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFormState state = ref.watch(onboardingControllerProvider);
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        // Back moves through the steps, not out of the flow: leaving is what
        // Skip is for, and a back arrow that abandons setup halfway is a trap.
        leading: state.isFirstStep
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: state.isSaving ? null : controller.back,
                tooltip: 'Back',
              ),
        // Present on both steps and in the same place, so skipping is never a
        // thing the user has to hunt for. A skip that is hard to find does not
        // make people finish; it makes them uninstall.
        actions: <Widget>[
          TextButton(
            onPressed: state.isSaving
                ? null
                : () => _finish(context, controller.skip),
            child: const Text('Skip'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        child: AppContentWidth(
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenInset,
                    AppSpacing.lg,
                    AppSpacing.screenInset,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      OnboardingStepHeader(
                        step: state.displayStep,
                        stepCount: OnboardingFormState.stepCount,
                        title: _titleFor(state.step),
                        subtitle: _subtitleFor(state.step),
                      ),
                      const SizedBox(height: AppSpacing.sectionGap),
                      // Keyed by step so switching does not carry the previous
                      // step's element state — a dropdown holding onto a value
                      // from a field that no longer exists.
                      KeyedSubtree(
                        key: ValueKey<int>(state.step),
                        child: switch (state.step) {
                          0 => _MoneyAndTimeStep(
                            setup: state.setup,
                            onCurrencyChanged: controller.setCurrency,
                            onTimeZoneChanged: controller.setTimeZone,
                          ),
                          _ => _RemindersStep(
                            setup: state.setup,
                            onEnabledChanged: controller.setRemindersEnabled,
                            onDayToggled: controller.toggleReminderDay,
                            onTimeChanged: controller.setReminderTime,
                          ),
                        },
                      ),
                      if (state.errorMessage
                          case final String message) ...<Widget>[
                        const SizedBox(height: AppSpacing.xl),
                        AppInlineMessage(
                          message: message,
                          tone: AppStatusTone.overdue,
                          icon: Icons.error_outline_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _OnboardingFooter(
                label: state.isLastStep ? 'Finish setup' : 'Continue',
                isBusy: state.isSaving,
                onPressed: state.isLastStep
                    ? () => _finish(context, controller.save)
                    : controller.next,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Runs a terminal action and leaves only if it succeeded.
  ///
  /// The controller reports failure through its own state, which is already on
  /// screen, so there is nothing to do here but stay put.
  Future<void> _finish(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final bool done = await action();

    // The await means this widget may be gone — the session could have ended and
    // the guard moved us to sign-in while the write was in flight.
    if (!done || !context.mounted) {
      return;
    }

    context.goNamed(AppRoutes.dashboard.routeName);
  }

  static String _titleFor(int step) => switch (step) {
    0 => 'Money and time',
    _ => 'When should we tell you?',
  };

  static String _subtitleFor(int step) => switch (step) {
    0 =>
      'Amounts are shown in this currency, and a bill counts as due based on '
          'the date where you are.',
    _ =>
      'A bill you hear about the day after it was due is just bad news. '
          'Pick when a reminder is still useful.',
  };
}

/// Step 1 — `profiles.currency` and `profiles.time_zone`.
class _MoneyAndTimeStep extends StatelessWidget {
  const _MoneyAndTimeStep({
    required this.setup,
    required this.onCurrencyChanged,
    required this.onTimeZoneChanged,
  });

  final AccountSetup setup;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<String> onTimeZoneChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppDropdownField<CurrencyOption>(
          label: 'Currency',
          items: SetupOptions.currencies,
          itemLabel: (CurrencyOption option) => option.description,
          value: SetupOptions.currencies.firstWhere(
            (CurrencyOption option) => option.code == setup.currency,
            // The guess is validated against the list it came from, so this is
            // unreachable — but a dropdown whose value is absent from its items
            // throws, and throwing on the first onboarding screen is not a
            // failure mode worth leaving open.
            orElse: () => SetupOptions.currencies.first,
          ),
          onChanged: (CurrencyOption? option) {
            if (option != null) {
              onCurrencyChanged(option.code);
            }
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        AppDropdownField<TimeZoneOption>(
          label: 'Time zone',
          items: SetupOptions.timeZones,
          itemLabel: (TimeZoneOption option) => option.label,
          value: SetupOptions.timeZones.firstWhere(
            (TimeZoneOption option) => option.name == setup.timeZone,
            orElse: () => SetupOptions.timeZones.first,
          ),
          onChanged: (TimeZoneOption? option) {
            if (option != null) {
              onTimeZoneChanged(option.name);
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _FieldNote(
          // Saying why the setting exists, in the terms it actually matters in.
          // "Time zone" on its own invites people to leave it wrong.
          text:
              'This decides which day a bill is due on. Set it to where you '
              'live, even if you are away right now.',
        ),
      ],
    );
  }
}

/// Step 2 — the three `reminder_preferences` columns.
class _RemindersStep extends StatelessWidget {
  const _RemindersStep({
    required this.setup,
    required this.onEnabledChanged,
    required this.onDayToggled,
    required this.onTimeChanged,
  });

  final AccountSetup setup;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onDayToggled;
  final ValueChanged<ReminderTime> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile.adaptive(
          value: setup.remindersEnabled,
          onChanged: onEnabledChanged,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Remind me about bills',
            style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
          ),
          subtitle: Text(
            'You can change this any time in Profile.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Remind me',
          style: textTheme.labelLarge?.copyWith(
            color: setup.remindersEnabled
                ? colors.textPrimary
                : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ReminderDaySelector(
          choices: SetupOptions.reminderDayChoices,
          selected: setup.reminderDaysBefore,
          onToggle: onDayToggled,
          // Left visible rather than hidden when reminders are off, so turning
          // the switch back on does not reveal a section that was never seen.
          enabled: setup.remindersEnabled,
        ),
        const SizedBox(height: AppSpacing.xl),
        _ReminderTimeField(
          time: setup.reminderTime,
          enabled: setup.remindersEnabled,
          onChanged: onTimeChanged,
        ),
      ],
    );
  }
}

/// The time of day reminders arrive, via the platform time picker.
class _ReminderTimeField extends StatelessWidget {
  const _ReminderTimeField({
    required this.time,
    required this.enabled,
    required this.onChanged,
  });

  final ReminderTime time;
  final bool enabled;
  final ValueChanged<ReminderTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    // Formatted through the framework's localisations rather than by hand, so a
    // device set to 24-hour time shows 21:00 and not 9:00 PM.
    final String formatted = TimeOfDay(
      hour: time.hour,
      minute: time.minute,
    ).format(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'At what time',
          style: textTheme.labelLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: enabled ? colors.surfaceInput : colors.disabled,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.md)),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: enabled ? colors.textSecondary : colors.onDisabled,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      formatted,
                      style: textTheme.bodyLarge?.copyWith(
                        color: enabled ? colors.textPrimary : colors.onDisabled,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: enabled ? colors.textSecondary : colors.onDisabled,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time.hour, minute: time.minute),
      helpText: 'Reminder time',
    );

    if (picked != null) {
      onChanged(ReminderTime(hour: picked.hour, minute: picked.minute));
    }
  }
}

class _FieldNote extends StatelessWidget {
  const _FieldNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: colors.textTertiary, height: 1.45),
    );
  }
}

/// The advancing action, pinned below the scroll.
///
/// Outside the scroll view on purpose: a wizard whose Continue button scrolls
/// out of view is a wizard people get stuck in.
class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.md,
        AppSpacing.screenInset,
        AppSpacing.lg,
      ),
      child: AppPrimaryButton(
        label: label,
        isBusy: isBusy,
        onPressed: isBusy ? null : onPressed,
      ),
    );
  }
}
