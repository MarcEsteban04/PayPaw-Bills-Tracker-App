import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// The small grey pills under a card title in the reference design — the ones
/// carrying the incidental facts about an item.
///
/// For PayPaw that is a bill's category, billing cycle, or payment method. It is
/// **not** for status; that is [AppStatusChip], which is coloured and carries
/// meaning. If everything is a chip, nothing stands out.
///
/// Deliberately not Material's `Chip`: that widget brings its own tap target,
/// delete affordance and padding model, all of which have to be argued back down
/// to reach this. A container is less code and matches the reference exactly.
class AppMetaChip extends StatelessWidget {
  const AppMetaChip({required this.label, this.icon, super.key});

  /// The fact, as short as it can be. 'Monthly', 'Electricity', 'GCash'.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final IconData iconData) ...<Widget>[
              Icon(iconData, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
