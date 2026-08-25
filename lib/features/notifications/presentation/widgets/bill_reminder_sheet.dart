import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/reminder_preferences.dart';
import '../../domain/entities/reminder_time.dart';
import '../controllers/notification_providers.dart';
import '../controllers/reminder_settings_controller.dart';
import 'reminder_day_selector.dart';
import 'reminder_time_field.dart';

/// One bill's departure from the reminder defaults.
///
/// ## Inherit is a state, not an absence
///
/// The sheet opens on "follow my settings" and stays there until the user
/// deliberately changes something. That is the shape of the table underneath —
/// every column nullable, null meaning inherit — and it is what keeps a bill
/// touched once in March from being frozen at March's settings forever.
///
/// So the controls are behind a switch. Turning it on copies the current
/// defaults in as a starting point, which is the honest default: a user opening
/// "customise" wants to change one thing about what they already have, not to
/// build a rule from nothing.
///
/// Turning it back off deletes the row rather than storing an override that
/// overrides nothing — see `ReminderPreferencesRepository.saveOverride`.
Future<void> showBillReminderSheet({
  required BuildContext context,
  required BillWithStatus item,
}) => showAppBottomSheet<void>(
  context: context,
  title: 'Reminders for this bill',
  child: _BillReminders(item: item),
);

class _BillReminders extends ConsumerStatefulWidget {
  const _BillReminders({required this.item});

  final BillWithStatus item;

  @override
  ConsumerState<_BillReminders> createState() => _BillRemindersState();
}

class _BillRemindersState extends ConsumerState<_BillReminders> {
  /// The offsets offered, matching the defaults screen.
  static const List<int> _choices = <int>[7, 3, 1, 0];

  /// The draft, or null while this bill follows the defaults.
  ///
  /// Local rather than written on every tap. Unlike the defaults screen — where
  /// each control is a complete decision — a per-bill rule is a small set of
  /// choices made together, and saving each keystroke would leave rows in the
  /// database for a customisation the user was still assembling and might
  /// abandon.
  BillReminderOverride? _draft;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AsyncValue<ReminderPreferences> defaultsAsync = ref.watch(
      reminderPreferencesProvider,
    );
    final AsyncValue<Map<String, BillReminderOverride>> storedAsync = ref.watch(
      billReminderOverridesProvider,
    );

    // Seeded once, and not until both have actually arrived.
    //
    // Reading `.value ?? {}` on the first build was a real bug: a bill *with* an
    // override opened as one following the defaults, because the query had not
    // come back yet — and Save then wrote the empty override that deletes its
    // row. Absence and not-yet-known are different answers and only one of them
    // is safe to act on.
    //
    // Once seeded it is never re-seeded, or the user's edits would be discarded
    // the moment any watched provider emitted.
    if (!_loaded && storedAsync.hasValue && defaultsAsync.hasValue) {
      _loaded = true;
      _draft = storedAsync.value![widget.item.bill.id];
    }

    if (!_loaded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: switch ((defaultsAsync, storedAsync)) {
          (AsyncError<ReminderPreferences>(), _) ||
          (_, AsyncError<Map<String, BillReminderOverride>>()) => Text(
            'Could not load this bill\'s reminders. Close this and try again.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          _ => const Center(child: AppLoadingIndicator()),
        },
      );
    }

    final ReminderPreferences defaults = defaultsAsync.value!;

    final bool isCustom = _draft != null;
    final ReminderPreferences rules = _draft?.resolve(defaults) ?? defaults;
    final bool isSaving = ref
        .watch(reminderSettingsControllerProvider)
        .isSaving;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.item.bill.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isCustom,
            onChanged: isSaving ? null : _setCustom,
            title: Text('Use different settings', style: textTheme.bodyLarge),
            subtitle: Text(
              isCustom
                  ? 'This bill ignores your defaults.'
                  : 'This bill follows your reminder settings.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: rules.isEnabled,
            onChanged: isCustom && !isSaving
                ? (bool value) => setState(
                    () => _draft = _draft!.copyWith(isEnabled: value),
                  )
                : null,
            title: Text('Remind me about it', style: textTheme.bodyLarge),
          ),

          const SizedBox(height: AppSpacing.md),
          Text(
            'Remind me',
            style: textTheme.labelLarge?.copyWith(
              color: isCustom && rules.isEnabled
                  ? colors.textPrimary
                  : colors.onDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ReminderDaySelector(
            choices: _choices,
            selected: rules.orderedOffsets,
            enabled: isCustom && rules.isEnabled && !isSaving,
            onToggle: _toggleDay,
          ),

          const SizedBox(height: AppSpacing.xl),
          ReminderTimeField(
            time: rules.timeOfDay,
            enabled: isCustom && rules.isEnabled && !isSaving,
            onChanged: (ReminderTime time) =>
                setState(() => _draft = _draft!.copyWith(timeOfDay: time)),
          ),

          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Save',
            isBusy: isSaving,
            onPressed: isSaving ? null : _save,
          ),
        ],
      ),
    );
  }

  /// Switches between following the defaults and departing from them.
  ///
  /// Turning it on copies the defaults in rather than starting empty. An empty
  /// override is one the repository would delete, so a switch that produced one
  /// would appear to do nothing at all.
  void _setCustom(bool value) {
    final ReminderPreferences defaults =
        ref.read(reminderPreferencesProvider).value ??
        const ReminderPreferences();

    setState(() {
      _draft = value
          ? BillReminderOverride(
              billId: widget.item.bill.id,
              isEnabled: defaults.isEnabled,
              daysBefore: defaults.orderedOffsets,
              timeOfDay: defaults.timeOfDay,
            )
          : null;
    });
  }

  /// Refuses to remove the last offset, like the defaults screen. The column's
  /// check demands at least one, and an empty set would mean reminders that are
  /// switched on and never arrive.
  void _toggleDay(int day) {
    final List<int> next = List<int>.of(_draft!.daysBefore ?? const <int>[]);

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

    setState(() => _draft = _draft!.copyWith(daysBefore: next));
  }

  Future<void> _save() async {
    // Null means "follow the defaults", which the repository stores as no row at
    // all. An empty override says the same thing, and sending one keeps the two
    // paths identical from here.
    final bool saved = await ref
        .read(reminderSettingsControllerProvider.notifier)
        .saveOverride(
          _draft ?? BillReminderOverride(billId: widget.item.bill.id),
        );

    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }
}
