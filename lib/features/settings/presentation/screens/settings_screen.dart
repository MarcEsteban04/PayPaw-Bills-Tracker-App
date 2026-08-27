import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/widgets/account_summary.dart';
import '../../../profile/presentation/widgets/profile_identity_card.dart';
import '../../../profile/presentation/widgets/time_zone_row.dart';
import '../widgets/appearance_section.dart';

/// Who you are, and everything about PayPaw you can change.
///
/// ## It is Settings, not Profile
///
/// It was called Profile because it started as one, and it stopped being one the
/// moment reminders, appearance and the time zone moved in. A tab labelled
/// Profile that opens a page of switches is a label arguing with its own
/// content, and the identity card at the top is what a settings screen leads
/// with everywhere else.
///
/// The `profile` feature keeps its name and its data — a `UserProfile` really is
/// a profile. This screen composes it.
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
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
              AppearanceSection(),
              SizedBox(height: AppSpacing.sectionGap),
              _DatesSection(),
              SizedBox(height: AppSpacing.sectionGap),
              AccountSummary(),
              _DeveloperSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the two galleries, in debug builds only.
///
/// Both have existed since the design system went in and neither had a door:
/// the only way to reach them was to edit the router's initial location, build,
/// look, and remember to put it back — which is how the app once shipped to the
/// phone opening on the component gallery instead of the dashboard.
///
/// Compiled out of release entirely. `kDebugMode` is a `const`, so the branch is
/// removed by the tree shaker rather than merely skipped, and nothing here
/// reaches a build a user installs.
class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        Text('Developer', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        const _SettingsTile(
          icon: Icons.widgets_outlined,
          title: 'Components',
          subtitle:
              'Every reusable widget, live — including all four hero moods',
          route: AppRoutes.components,
        ),
        const SizedBox(height: AppSpacing.md),
        const _SettingsTile(
          icon: Icons.palette_outlined,
          title: 'Design system',
          subtitle: 'Colour, type and spacing tokens as the app resolves them',
          route: AppRoutes.designSystem,
        ),
      ],
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
