import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/notifications/domain/entities/bill_reminder_override.dart';
import 'package:paypaw/features/notifications/domain/entities/reminder_preferences.dart';
import 'package:paypaw/features/notifications/domain/repositories/reminder_preferences_repository.dart';

/// An in-memory [ReminderPreferencesRepository].
///
/// Holds what was written so a screen with no Save button can be checked on the
/// only thing that matters about it: that the tap reached the database.
///
/// [failWith] makes every write fail, which is the other half — a screen where
/// each control saves itself has nowhere to put a failure except a message, and
/// a silent one reads as the tap never registering.
class FakeReminderPreferencesRepository
    implements ReminderPreferencesRepository {
  FakeReminderPreferencesRepository({
    this.preferences = const ReminderPreferences(),
    Map<String, BillReminderOverride>? overrides,
    this.failWith,
  }) : overrides = <String, BillReminderOverride>{...?overrides};

  ReminderPreferences preferences;
  final Map<String, BillReminderOverride> overrides;

  /// What every write throws, or null if they succeed.
  AppException? failWith;

  /// Every set of defaults written, in order.
  final List<ReminderPreferences> saved = <ReminderPreferences>[];

  /// Every override written, in order. A deletion appears here as the empty
  /// override that asked for it.
  final List<BillReminderOverride> savedOverrides = <BillReminderOverride>[];

  @override
  Future<ReminderPreferences> fetch() async => preferences;

  @override
  Future<void> save(ReminderPreferences preferences) async {
    _failIfAsked();

    saved.add(preferences);
    this.preferences = preferences;
  }

  @override
  Future<Map<String, BillReminderOverride>> fetchOverrides() async =>
      Map<String, BillReminderOverride>.of(overrides);

  @override
  Future<void> saveOverride(BillReminderOverride override) async {
    _failIfAsked();

    savedOverrides.add(override);

    // Mirrors the real one: an override that overrides nothing is a deletion,
    // not a row.
    if (override.isEmpty) {
      overrides.remove(override.billId);
    } else {
      overrides[override.billId] = override;
    }
  }

  void _failIfAsked() {
    if (failWith case final AppException exception) {
      throw exception;
    }
  }
}
