import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_filter_pill.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/widgets/account_summary.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/time_zone_row.dart';

/// Who you are, and everything about PayPaw you can change.
///
/// ## It stopped being a placeholder
///
/// For forty-odd sprints this was a `ScreenPlaceholder` promising "account,
/// categories, reminders, security and app settings... built in Sprints 54 and
/// 78-80" — with the real controls bolted underneath it. Two of those things now
/// exist, the sprint numbers pointed at debt and security work that has nothing
/// to do with this screen, and a card explaining what a screen will one day be
/// is furniture on a screen that already is.
///
/// ## The order is: who, then what you'd change, then leaving
///
/// Identity first, because it is the answer to "whose account is this" and it is
/// the one thing here that was missing entirely. Then the settings, commonest
/// first. **Sign out is last**, deliberately: it is the only disruptive control
/// on the screen, and putting it under everything else is the cheapest way to
/// keep a stray thumb off it.
///
/// Categories are not here. They are edited where they are used — on the bill
/// form — and a second place to manage them would be a second place for the two
/// to disagree.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: AppContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenInset,
              AppSpacing.lg,
              AppSpacing.screenInset,
              AppSpacing.bottomNavClearance,
            ),
            children: const <Widget>[
              ProfileIdentityCard(),
              SizedBox(height: AppSpacing.sectionGap),
              _NotificationsSection(),
              SizedBox(height: AppSpacing.sectionGap),
              _AppearanceSection(),
              SizedBox(height: AppSpacing.sectionGap),
              _DatesSection(),
              SizedBox(height: AppSpacing.sectionGap),
              _DeveloperTools(),
              SizedBox(height: AppSpacing.sectionGap),
              AccountSummary(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The setting that decides what "today" means.
///
/// Its own section rather than a row among the others, because it is not a
/// preference — see [TimeZoneRow]. A wrong zone here is wrong dates everywhere
/// else, and nothing on any other screen would give the reason.
class _DatesSection extends StatelessWidget {
  const _DatesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Dates', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        const TimeZoneRow(),
      ],
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
