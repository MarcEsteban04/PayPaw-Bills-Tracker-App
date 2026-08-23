import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/screen_placeholder.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// Account, settings, and the feature areas used occasionally rather than daily.
///
/// Placeholder, apart from the developer tools below — which are real, and are
/// how the design system gallery is reached now that the dashboard owns the
/// initial route.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScreenPlaceholder(
      title: 'Profile',
      icon: Icons.person_rounded,
      description:
          'Account, categories, reminders, security and app settings, plus '
          'analytics and payment streaks.',
      buildsIn: 'Sprints 54 and 78-80',
      footer: _DeveloperTools(),
    );
  }
}

/// Entry points that exist for development, not for users.
///
/// Removed, or moved behind a debug-only flag, before release.
class _DeveloperTools extends StatelessWidget {
  const _DeveloperTools();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Developer', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        // A Material, not a DecoratedBox: ListTile paints its ink splash on the
        // nearest Material ancestor, so a decorated box in between would hide
        // the tap feedback entirely.
        Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.card,
            side: BorderSide(color: AppColors.border),
          ),
          child: ListTile(
            leading: const Icon(
              Icons.palette_outlined,
              color: AppColors.primaryText,
            ),
            title: Text('Design system', style: textTheme.titleSmall),
            subtitle: Text(
              'Every colour, type size, radius and shadow',
              style: textTheme.bodySmall,
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
            onTap: () => context.pushNamed(AppRoutes.designSystem.routeName),
          ),
        ),
      ],
    );
  }
}
