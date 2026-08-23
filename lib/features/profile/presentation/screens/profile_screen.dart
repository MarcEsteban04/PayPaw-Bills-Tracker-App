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
/// how the token and component galleries are reached.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Developer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        const _DeveloperTile(
          icon: Icons.palette_outlined,
          title: 'Design system',
          subtitle: 'Every colour, type size, radius and shadow',
          route: AppRoutes.designSystem,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _DeveloperTile(
          icon: Icons.widgets_outlined,
          title: 'Components',
          subtitle: 'Buttons, cards, inputs, chips, sheets and states',
          route: AppRoutes.components,
        ),
      ],
    );
  }
}

class _DeveloperTile extends StatelessWidget {
  const _DeveloperTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppRoutes route;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    // A Material, not a DecoratedBox: ListTile paints its ink splash on the
    // nearest Material ancestor, so a decorated box in between would hide the
    // tap feedback entirely.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryText),
        title: Text(title, style: textTheme.titleSmall),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
        ),
        onTap: () => context.pushNamed(route.routeName),
      ),
    );
  }
}
