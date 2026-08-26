import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../controllers/profile_providers.dart';

/// The zone this account's dates are computed in.
///
/// ## Why this is on the screen at all
///
/// It looks like a preference and it is not. `bill_status` decides "due today"
/// against `profiles.time_zone`, and `generate_recurring_bills` measures its
/// horizon by it — so a wrong zone is wrong **dates**. A bill can read as due
/// tomorrow when it was due yesterday, and nothing on any other screen would
/// give the reason.
///
/// It defaults to Asia/Manila for every account, because the migration had to
/// choose something. Anybody who is not there has had silently wrong dates since
/// they signed up, with no way to find out.
///
/// ## Why there is no picker
///
/// A list of four hundred IANA names is a worse control than the one question
/// worth asking: *is this the zone you are actually in?* The phone already
/// knows, so the row shows both and offers to match — one tap, no scrolling, and
/// it cannot produce a zone that does not exist.
///
/// Somebody who genuinely wants a zone their phone is not in is not served by
/// this. That is a real gap and a rarer one than the default being wrong.
class TimeZoneRow extends ConsumerWidget {
  const TimeZoneRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String? stored = ref.watch(userProfileProvider).value?.timeZone;
    final String? device = ref.watch(deviceTimeZoneProvider).value;

    if (stored == null) {
      return const SizedBox.shrink();
    }

    final bool matches = device == null || device == stored;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardInset),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.panel,
        border: colors.surfaceBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.public_outlined,
                size: 20,
                color: matches ? colors.textTertiary : colors.dueSoonText,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Time zone',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      stored,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!matches) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your phone says $device. Due dates and reminders are worked out '
              'in the zone above, so they may be a day out.',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: ref.watch(profileControllerProvider).isSaving
                    ? null
                    : () => _match(context, ref, device),
                child: Text('Use $device'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _match(BuildContext context, WidgetRef ref, String zone) async {
    final bool saved = await ref
        .read(profileControllerProvider.notifier)
        .saveTimeZone(zone);

    if (!context.mounted) {
      return;
    }

    if (!saved) {
      showAppToast(
        context,
        message: 'Could not change your time zone. Please try again.',
        tone: AppToastTone.error,
      );
      return;
    }

    // Every status on every screen was computed in the old zone. `bill_status`
    // is a view, so the rows are simply recomputed on the next read — but only
    // if something asks for one.
    ref.invalidate(billsProvider);

    showAppToast(
      context,
      message: 'Time zone set to $zone',
      tone: AppToastTone.success,
    );
  }
}

/// The zone the phone is in, as an IANA name.
///
/// A provider so a test can answer it without a platform channel, and so the
/// row and the notification service are not each asking the plugin separately.
final FutureProvider<String?> deviceTimeZoneProvider = FutureProvider<String?>((
  Ref ref,
) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    // A platform that cannot say. The row then shows the stored zone with
    // no comparison, which is honest: PayPaw does not know any better.
    return null;
  }
});
