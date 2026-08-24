import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// "Step 1 of 2", a title, and a line saying why the step exists.
///
/// The progress indicator is a pair of bars rather than a dot carousel: two
/// segments read as "short" at a glance, where dots read as "some unknown
/// number of these". With only two steps, telling the user it is nearly over is
/// most of the value the header has.
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    required this.step,
    required this.stepCount,
    required this.title,
    required this.subtitle,
    super.key,
  });

  /// 1-based.
  final int step;
  final int stepCount;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          // The bars are decorative; this is the part that is read out.
          label: 'Step $step of $stepCount',
          child: Row(
            children: <Widget>[
              for (int index = 1; index <= stepCount; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == stepCount ? 0 : AppSpacing.sm,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: index <= step ? colors.primary : colors.border,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppRadii.pill),
                        ),
                      ),
                      child: const SizedBox(height: 4),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
