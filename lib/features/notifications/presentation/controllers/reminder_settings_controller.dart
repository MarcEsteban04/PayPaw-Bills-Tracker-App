import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/bill_reminder_override.dart';
import '../../domain/entities/reminder_preferences.dart';
import 'notification_providers.dart';

/// Whether a reminder setting is being written, and what it said if it failed.
class ReminderSettingsState {
  const ReminderSettingsState({this.isSaving = false, this.errorMessage});

  final bool isSaving;

  /// A failure, in words safe to show.
  final String? errorMessage;

  ReminderSettingsState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) => ReminderSettingsState(
    isSaving: isSaving ?? this.isSaving,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Writes reminder settings, both the defaults and one bill's override.
///
/// ## Saved on change, not on a Save button
///
/// Every control here is a switch, a toggle or a picker, and each one is a
/// complete decision on its own. A form that collects four of those and then
/// asks the user to confirm them is a form that can be abandoned halfway,
/// leaving them unsure which half took.
///
/// The cost is that a failed write has to be visible, since there is no button
/// left sitting there to retry — hence [ReminderSettingsState.errorMessage], and
/// the screen showing it rather than swallowing it.
///
/// ## It does not reschedule anything
///
/// Saving invalidates the provider the schedule is built from, and `ReminderSync`
/// is listening. That is the same route every bill write already takes, and it
/// is why this controller has no idea notifications exist.
class ReminderSettingsController extends Notifier<ReminderSettingsState> {
  @override
  ReminderSettingsState build() => const ReminderSettingsState();

  /// Stores the user's defaults. True if it landed.
  Future<bool> saveDefaults(ReminderPreferences preferences) =>
      _write(() async {
        await ref.read(reminderPreferencesRepositoryProvider).save(preferences);

        ref.invalidate(reminderPreferencesProvider);
      });

  /// Stores one bill's departure from them, or removes it. True if it landed.
  Future<bool> saveOverride(BillReminderOverride override) => _write(() async {
    await ref
        .read(reminderPreferencesRepositoryProvider)
        .saveOverride(override);

    ref.invalidate(billReminderOverridesProvider);
  });

  Future<bool> _write(Future<void> Function() action) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await action();

      state = state.copyWith(isSaving: false);
      return true;
    } on AppException catch (exception) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: exception.userMessage,
      );
      return false;
    } on Object {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }
}

final NotifierProvider<ReminderSettingsController, ReminderSettingsState>
reminderSettingsControllerProvider =
    NotifierProvider<ReminderSettingsController, ReminderSettingsState>(
      ReminderSettingsController.new,
    );
