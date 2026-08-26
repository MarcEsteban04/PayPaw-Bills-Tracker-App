import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_write_controller.dart';

/// What the user chose to do from the detail sheet.
enum SubscriptionAction { edit, pause, resume, copyCancellationLink, delete }

/// Everything known about one subscription, in a drawer.
///
/// Opens the sheet and acts on whatever came back. The sheet returns an intent
/// rather than doing the work itself: navigation and dialogs need a context that
/// outlives the sheet, and a widget that pops itself and then keeps working is a
/// widget that eventually uses a dead context.
Future<void> showSubscriptionDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Subscription subscription,
  required DateTime today,
}) async {
  final SubscriptionAction? action =
      await showAppBottomSheet<SubscriptionAction>(
        context: context,
        child: _SubscriptionDetail(subscription: subscription, today: today),
      );

  if (!context.mounted || action == null) {
    return;
  }

  final SubscriptionWriteController controller = ref.read(
    subscriptionWriteControllerProvider.notifier,
  );

  switch (action) {
    case SubscriptionAction.edit:
      unawaited(
        context.pushNamed(
          AppRoutes.editSubscription.routeName,
          pathParameters: <String, String>{'id': subscription.id},
        ),
      );
    case SubscriptionAction.pause:
      await controller.setActive(subscription.template, isActive: false);
    case SubscriptionAction.resume:
      await controller.setActive(subscription.template, isActive: true);
    case SubscriptionAction.copyCancellationLink:
      await _copyLink(context, subscription);
    case SubscriptionAction.delete:
      await _confirmDelete(context, controller, subscription);
  }
}

/// Puts the cancellation link on the clipboard.
///
/// Copied rather than opened. Opening it needs `url_launcher` and an Android
/// `<queries>` entry for the browser intent — a new dependency and a manifest
/// change for a field most subscriptions will not have filled in. Worth doing
/// the moment somebody actually uses it; not worth doing on spec.
Future<void> _copyLink(BuildContext context, Subscription subscription) async {
  final String? url = subscription.details.cancellationUrl;

  if (url == null) {
    return;
  }

  await Clipboard.setData(ClipboardData(text: url));

  if (context.mounted) {
    showAppToast(
      context,
      message: 'Cancellation link copied',
      tone: AppToastTone.success,
    );
  }
}

/// Asks before deleting, and says what survives.
Future<void> _confirmDelete(
  BuildContext context,
  SubscriptionWriteController controller,
  Subscription subscription,
) async {
  final bool confirmed = await showAppConfirmDialog(
    context: context,
    title: 'Delete ${subscription.details.provider}?',
    // What actually happens, rather than "are you sure". PayPaw cannot cancel
    // anything with the provider, and letting somebody believe it did would be
    // the worst failure this screen could have.
    message:
        'This removes it from PayPaw and stops it making new bills. It does '
        'not cancel anything with ${subscription.details.provider} — you have '
        'to do that with them. Bills it already made stay where they are.',
    confirmLabel: 'Delete',
    isDestructive: true,
  );

  if (!confirmed) {
    return;
  }

  final bool deleted = await controller.delete(subscription.id);

  if (deleted && context.mounted) {
    showAppToast(
      context,
      message: '${subscription.details.provider} deleted',
      tone: AppToastTone.success,
    );
  }
}

class _SubscriptionDetail extends StatelessWidget {
  const _SubscriptionDetail({required this.subscription, required this.today});

  final Subscription subscription;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isPaused = !subscription.isActive;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            subscription.providerLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // The figure the drawer exists to show, at the size that says so.
          Text(
            'EVERY ${subscription.recurrence.describe().toUpperCase()}',
            style: textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subscription.amount.format(),
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: AppSpacing.lg),

          _Fact(
            icon: Icons.event_repeat_outlined,
            label: isPaused ? 'Would have charged' : 'Charges next',
            value: DateFormat.yMMMEd().format(subscription.nextBillingOn),
          ),
          if (subscription.name.trim() !=
              subscription.details.provider.trim()) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Fact(
              icon: Icons.label_outline_rounded,
              label: 'Called',
              value: subscription.name,
            ),
          ],
          if (subscription.details.trialEndsOn
              case final DateTime ends) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _Fact(
              icon: Icons.hourglass_bottom_rounded,
              label: subscription.isInTrial(today)
                  ? 'Trial ends'
                  : 'Trial ended',
              value: DateFormat.yMMMEd().format(ends),
              tone: subscription.isInTrial(today) ? colors.dueSoonText : null,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Fact(
            icon: subscription.willRenew
                ? Icons.autorenew_rounded
                : Icons.block_outlined,
            label: 'Renewal',
            value: switch ((isPaused, subscription.details.autoRenews)) {
              (true, _) => 'Stopped in PayPaw',
              (false, true) => 'Renews automatically',
              (false, false) => 'Set not to renew',
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          if (subscription.details.hasCancellationLink) ...<Widget>[
            _Action(
              icon: Icons.link_rounded,
              label: 'Copy cancellation link',
              onPressed: () =>
                  Navigator.of(context)
                      .pop(SubscriptionAction.copyCancellationLink),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _Action(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onPressed: () => Navigator.of(context).pop(SubscriptionAction.edit),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: isPaused ? 'Start it again' : 'Stop it for now',
            onPressed: () => Navigator.of(context).pop(
              isPaused ? SubscriptionAction.resume : SubscriptionAction.pause,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            isDestructive: true,
            onPressed: () =>
                Navigator.of(context).pop(SubscriptionAction.delete),
          ),
        ],
      ),
    );
  }
}

/// One labelled fact.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String value;

  /// A colour for the value where the value is itself a warning.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: AppRadii.chip,
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  color: tone ?? colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One thing you can do, as a full-width row.
///
/// Rows rather than the bill drawer's circle of icons: there are four here and
/// two of them — stopping and deleting — are close enough in effect that an icon
/// alone would be a coin toss.
class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color foreground = isDestructive
        ? colors.overdueText
        : colors.textPrimary;

    return Material(
      color: isDestructive ? colors.overdueTint : colors.surfaceMuted,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
