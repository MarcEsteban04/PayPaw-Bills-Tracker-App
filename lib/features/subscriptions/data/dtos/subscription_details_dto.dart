import '../../domain/entities/subscription_details.dart';

/// Maps a `public.subscriptions` row to [SubscriptionDetails].
///
/// Column names have to match `0006_subscriptions.sql` exactly, and a mismatch
/// is a runtime failure rather than a compile error — which is the whole reason
/// a hand-written mapper gets its own test.
abstract final class SubscriptionDetailsDto {
  static const String tableName = 'subscriptions';

  static const String columnRecurringBillId = 'recurring_bill_id';
  static const String columnUserId = 'user_id';
  static const String columnProvider = 'provider';
  static const String columnPlanName = 'plan_name';
  static const String columnTrialEndsOn = 'trial_ends_on';
  static const String columnAutoRenews = 'auto_renews';
  static const String columnCancellationUrl = 'cancellation_url';

  static const String selectColumns =
      '$columnRecurringBillId, $columnProvider, $columnPlanName, '
      '$columnTrialEndsOn, $columnAutoRenews, $columnCancellationUrl';

  static SubscriptionDetails toEntity(Map<String, dynamic> row) =>
      SubscriptionDetails(
        recurringBillId: row[columnRecurringBillId] as String? ?? '',
        provider: row[columnProvider] as String? ?? '',
        planName: _text(row[columnPlanName]),
        trialEndsOn: _date(row[columnTrialEndsOn]),
        // The column is `not null default true`, so a null here means a row
        // written before the column existed. Renewing is the assumption that
        // costs a user least: it is what almost every subscription does, and
        // being warned about one that had already stopped is a smaller failure
        // than not being warned about one that had not.
        autoRenews: row[columnAutoRenews] as bool? ?? true,
        cancellationUrl: _text(row[columnCancellationUrl]),
      );

  /// Values for an upsert, keyed on the recurring bill.
  ///
  /// **`user_id` is carried.** It is denormalised on this table so the RLS
  /// policy is a column comparison rather than a join, which means an inserted
  /// row cannot be attributed without it — see the comment in migration 0006.
  ///
  /// **Nulls are sent, not omitted.** A trial date or a cancellation link
  /// cleared back to nothing has to overwrite what was stored, and a map without
  /// the key would leave the old value in place.
  static Map<String, dynamic> toUpsert(
    SubscriptionDetails details, {
    required String userId,
  }) => <String, dynamic>{
    columnRecurringBillId: details.recurringBillId,
    columnUserId: userId,
    columnProvider: details.provider.trim(),
    columnPlanName: _text(details.planName),
    columnTrialEndsOn: _wireDate(details.trialEndsOn),
    columnAutoRenews: details.autoRenews,
    columnCancellationUrl: _text(details.cancellationUrl),
  };

  /// A trimmed string, or null if there is nothing left of it.
  static String? _text(Object? value) {
    if (value is! String) {
      return null;
    }

    final String trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  /// A `date` column arrives as 'YYYY-MM-DD'.
  ///
  /// Parsed rather than trusted: an unreadable date costs the trial warning, not
  /// the whole subscription. A row that will not map at all is a subscription
  /// the user cannot see or cancel.
  static DateTime? _date(Object? value) {
    if (value is! String) {
      return null;
    }

    return DateTime.tryParse(value);
  }

  /// Date only, because the column is a `date` and a timestamp would be
  /// truncated by Postgres in whatever zone it felt like.
  static String? _wireDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');

    return '${value.year}-$month-$day';
  }
}
