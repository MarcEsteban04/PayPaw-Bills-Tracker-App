import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// Stands in for a screen that has not been built yet.
///
/// **Temporary.** Each use is deleted when its real screen arrives — the
/// [buildsIn] label says which sprint that is. It exists so the navigation
/// hierarchy is walkable and testable now, rather than after every screen is
/// finished.
class ScreenPlaceholder extends StatelessWidget {
  const ScreenPlaceholder({
    required this.title,
    required this.icon,
    required this.description,
    required this.buildsIn,
    this.footer,
    super.key,
  });

  /// Screen title, shown in the app bar.
  final String title;

  /// Icon representing this area of the app.
  final IconData icon;

  /// One line on what this screen will do.
  final String description;

  /// Which sprint replaces this, e.g. `'Sprints 34-38'`.
  final String buildsIn;

  /// Optional extra content below the message — used by Profile to expose
  /// developer tools while the real screen does not exist.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          AppSpacing.lg,
          AppSpacing.screenInset,
          AppSpacing.bottomNavClearance,
        ),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadii.panel,
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: <Widget>[
                // Decorative: the description below says what this screen is
                // for, so announcing the icon too would only add noise.
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      borderRadius: AppRadii.card,
                    ),
                    child: Icon(
                      icon,
                      color: context.colors.primaryText,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Built in $buildsIn',
                  textAlign: TextAlign.center,
                  style: textTheme.labelMedium,
                ),
              ],
            ),
          ),
          if (footer case final Widget content) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            content,
          ],
        ],
      ),
    );
  }
}
