import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_filter_pill.dart';
import '../../../../core/presentation/widgets/screen_placeholder.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/widgets/account_summary.dart';

/// Account, settings, and the feature areas used occasionally rather than daily.
///
/// Placeholder, apart from the appearance control and the developer tools below,
/// which are real. Appearance lives here because Sprint 10 needs somewhere to
/// switch themes from; it moves into the real settings screen when that is built.
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
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AccountSummary(),
          SizedBox(height: AppSpacing.sectionGap),
          _NotificationsSection(),
          SizedBox(height: AppSpacing.sectionGap),
          _AppearanceSection(),
          SizedBox(height: AppSpacing.sectionGap),
          _DeveloperTools(),
        ],
      ),
    );
  }
}

/// Where onboarding has always said to look.
///
/// "You can change this any time in Profile" has been on the onboarding screen
/// since Sprint 11B, and until Sprint 42 there was nothing here to change. This
/// row is that sentence becoming true.
class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Notifications', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        const _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Reminders',
          subtitle: 'When to be warned a bill is due, and whether at all',
          route: AppRoutes.reminderSettings,
        ),
      ],
    );
  }
}

/// Light, dark, or follow the device.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode current = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: <Widget>[
            for (final ThemeMode mode in ThemeMode.values)
              // The filter pill already carries a selected state and the right
              // geometry, so this reuses it rather than adding a fourth kind of
              // toggle to the component kit.
              AppFilterPill(
                label: _label(mode),
                isApplied: mode == current,
                showCaret: false,
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).setThemeMode(mode),
              ),
          ],
        ),
      ],
    );
  }

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
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
        const _SettingsTile(
          icon: Icons.palette_outlined,
          title: 'Design system',
          subtitle: 'Every colour, type size, radius and shadow',
          route: AppRoutes.designSystem,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _SettingsTile(
          icon: Icons.widgets_outlined,
          title: 'Components',
          subtitle: 'Buttons, cards, inputs, chips, sheets and states',
          route: AppRoutes.components,
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
    final AppPalette palette = context.colors;

    // A Material, not a DecoratedBox: ListTile paints its ink splash on the
    // nearest Material ancestor, so a decorated box in between would hide the
    // tap feedback entirely.
    return Material(
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.card,
        side: BorderSide(color: palette.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: palette.primaryText),
        title: Text(title, style: textTheme.titleSmall),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: palette.textTertiary,
        ),
        onTap: () => context.pushNamed(route.routeName),
      ),
    );
  }
}
