import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_mode_controller.dart';

/// Light, dark, or follow the device — shown rather than described.
///
/// ## Why this is not three words in a row
///
/// It was: three `AppFilterPill`s, borrowed from the bills screen. Two things
/// were wrong with that. A filter pill *narrows a list*, so the control was
/// wearing the wrong metaphor and looked borrowed because it was. And a theme is
/// the one setting in the app whose whole subject is what things look like —
/// describing it in words when it could simply be drawn was giving up the one
/// advantage the setting has.
///
/// Each option is a small picture of the app in that theme, painted from the
/// real palettes rather than approximations. A reader who does not know what
/// "System" means can see it: half of that tile is light and half is dark.
///
/// ## The line underneath
///
/// Only for System, and only because System is the one option whose name does
/// not say what it will do. "Following your phone, which is dark right now"
/// answers the question the other two never raise.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final ThemeMode current = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Appearance', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardInset),
          decoration: BoxDecoration(
            // A card, like every other section on this screen. The pills used to
            // float bare on the canvas, which is why they read as leftovers from
            // somewhere else.
            color: colors.surface,
            borderRadius: AppRadii.panel,
            border: colors.surfaceBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  for (final ThemeMode mode in ThemeMode.values) ...<Widget>[
                    if (mode != ThemeMode.values.first)
                      const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _ThemeOption(
                        mode: mode,
                        isSelected: mode == current,
                        onTap: () => ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(mode),
                      ),
                    ),
                  ],
                ],
              ),
              if (current == ThemeMode.system) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Following your phone, which is '
                  '${MediaQuery.platformBrightnessOf(context) == Brightness.dark ? 'dark' : 'light'} '
                  'right now.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One choice: a picture of the app, its name, and whether it is the one in use.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: _label(mode),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              // Not phone-shaped. A tall tile at a third of the card's width
              // read as a phone drawn inside a phone — the frame became the
              // subject and the colours, which are the actual subject, got the
              // leftovers. Nearly square is a swatch of the app instead.
              aspectRatio: 0.92,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: AppRadii.card,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Padding(
                  // Inside the border, so the preview does not paint over it.
                  padding: const EdgeInsets.all(2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.md - 2),
                    child: _Preview(mode: mode),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (isSelected) ...<Widget>[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: colors.primaryText,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                ],
                Flexible(
                  child: Text(
                    _label(mode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colors.primaryText
                          : colors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The app, in miniature.
///
/// Painted from `AppPalette.light` and `AppPalette.dark` directly rather than
/// from the active theme — the light tile has to look light while the app is
/// dark, which is the entire point of showing it.
class _Preview extends StatelessWidget {
  const _Preview({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      ThemeMode.light => const _Miniature(palette: AppPalette.light),
      ThemeMode.dark => const _Miniature(palette: AppPalette.dark),
      // Split corner to corner: the standard way to say "whichever your phone
      // is", and the only one of the three that needs no caption to be read.
      ThemeMode.system => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _Miniature(palette: AppPalette.dark),
          ClipPath(
            clipper: const _TopLeftTriangle(),
            child: const _Miniature(palette: AppPalette.light),
          ),
        ],
      ),
    };
  }
}

/// Everything above the diagonal.
class _TopLeftTriangle extends CustomClipper<Path> {
  const _TopLeftTriangle();

  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A card, two lines of text and the accent, on the canvas.
///
/// Not a screenshot and not a real widget tree: the four colours a reader
/// actually judges a theme by are the background, the card on it, the text and
/// the accent, and those are what this shows.
class _Miniature extends StatelessWidget {
  const _Miniature({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: palette.canvas),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // A heading, then two cards on the canvas — which is what every
            // screen in this app is. Cards that reach nearly the full width read
            // as content; the narrow inset one that was here before read as a
            // device outline.
            Align(
              alignment: Alignment.centerLeft,
              child: _Bar(color: palette.textPrimary, width: 20, height: 4),
            ),
            const SizedBox(height: 6),
            Expanded(
              flex: 5,
              child: _Card(
                palette: palette,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _Bar(color: palette.textSecondary, width: 24, height: 3),
                    // The accent, which is the colour the whole app is
                    // recognised by and the one a theme has to get right.
                    _Bar(color: palette.primary, width: 16, height: 5),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              flex: 3,
              child: _Card(
                palette: palette,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _Bar(
                    color: palette.textTertiary,
                    width: 18,
                    height: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the cards on the miniature canvas.
class _Card extends StatelessWidget {
  const _Card({required this.palette, required this.child});

  final AppPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(4),
        // The dark theme's surface is a few levels off its canvas, so without
        // the outline the card would be invisible in exactly the preview a
        // reader is trying to judge.
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.width, required this.height});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
