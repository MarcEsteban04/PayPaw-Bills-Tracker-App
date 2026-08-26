import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/subscriptions/domain/entities/subscription_details.dart';
import 'package:paypaw/features/subscriptions/domain/repositories/subscription_details_store.dart';

/// An in-memory [SubscriptionDetailsStore].
///
/// [failSave] is the reason this exists: the half-written create is the one
/// failure the repository has real logic for, and without a store that can be
/// made to fail it could only be reasoned about.
class FakeSubscriptionDetailsStore implements SubscriptionDetailsStore {
  FakeSubscriptionDetailsStore({
    Map<String, SubscriptionDetails>? rows,
    this.failSave,
  }) : rows = <String, SubscriptionDetails>{...?rows};

  final Map<String, SubscriptionDetails> rows;

  /// What [save] throws, or null if it succeeds.
  AppException? failSave;

  final List<SubscriptionDetails> saved = <SubscriptionDetails>[];

  @override
  Future<Map<String, SubscriptionDetails>> fetchAll() async =>
      Map<String, SubscriptionDetails>.of(rows);

  @override
  Future<SubscriptionDetails?> fetch(String recurringBillId) async =>
      rows[recurringBillId];

  @override
  Future<SubscriptionDetails> save(SubscriptionDetails details) async {
    if (failSave case final AppException exception) {
      throw exception;
    }

    saved.add(details);
    rows[details.recurringBillId] = details;

    return details;
  }
}
