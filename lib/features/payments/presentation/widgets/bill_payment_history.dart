import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/payment_method.dart';
import '../controllers/payment_providers.dart';

/// What has been paid against one bill, most recent first.
///
/// ## Only rendered when there is something to render
///
/// The caller decides that, from the total the `bill_status` view already
/// returned: `amount_minor > 0` is a check constraint on the table, so a bill
/// whose paid total is zero has no payment rows and this would be an empty
/// section under a heading — a small daily untruth, and a wasted query on every
/// drawer of every unpaid bill.
///
/// ## A failure here does not take the drawer with it
///
/// The history is the one part of the drawer that needs a second round trip.
/// Everything above it came from the row the list already had, so a network
/// failure degrades to a line of text rather than an error screen replacing facts
/// that were never in doubt.
class BillPaymentHistory extends ConsumerWidget {
  const BillPaymentHistory({required this.billId, super.key});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'PAYMENT HISTORY',
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        switch (ref.watch(paymentsForBillProvider(billId))) {
          AsyncLoading<List<Payment>>() => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: AppLoadingIndicator(),
          ),
          AsyncError<List<Payment>>() => Text(
            'Could not load the payments. Pull the list to refresh.',
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          // Reachable despite the caller's check: the totals came from the view
          // and the rows come from the table, so a payment deleted between the
          // two lands here. Says so rather than showing a heading over nothing.
          AsyncData<List<Payment>>(value: final List<Payment> rows)
              when rows.isEmpty =>
            Text(
              'No payments recorded.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          AsyncData<List<Payment>>(value: final List<Payment> rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final Payment payment in rows) ...<Widget>[
                _PaymentRow(payment: payment),
                if (payment != rows.last) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        },
      ],
    );
  }
}

/// One payment: what moved, when, and how.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(_icon(payment.method), size: 18, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    // The date, not the method, is the first thing read. "Did
                    // the one I sent on Tuesday go through" is the question a
                    // history answers.
                    DateFormat.yMMMd().format(payment.paidAt),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_subtitle(payment) case final String line) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      line,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              payment.amount.format(),
              style: textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The method and the receipt number, whichever of them exist.
  ///
  /// Null when neither does, so the row is one clean line rather than one line
  /// and an empty second.
  static String? _subtitle(Payment payment) {
    final List<String> parts = <String>[
      if (payment.method?.label case final String label) label,
      if (payment.reference case final String reference) 'Ref $reference',
    ];

    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A method the build does not recognise falls back to the generic receipt,
  /// which is true of every payment.
  static IconData _icon(PaymentMethod? method) => switch (method) {
    PaymentMethod.gcash || PaymentMethod.maya => Icons.smartphone_outlined,
    PaymentMethod.bankTransfer => Icons.account_balance_outlined,
    PaymentMethod.card => Icons.credit_card_outlined,
    PaymentMethod.cash => Icons.payments_outlined,
    PaymentMethod.autoDebit => Icons.autorenew_rounded,
    PaymentMethod.other || null => Icons.receipt_long_outlined,
  };
}
