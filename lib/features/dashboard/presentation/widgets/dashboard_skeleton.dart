import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import 'dashboard_cards.dart';
import 'dashboard_quick_actions.dart';

/// What the dashboard looks like before its bills arrive.
///
/// ## Shaped after what is coming, not after a rectangle
///
/// It replaced three plain blocks of arbitrary height. Those were honest about
/// *something* loading and wrong about everything else: the screen jumped when
/// the data landed, because nothing that arrived was the shape of what had been
/// standing in for it. A skeleton exists precisely to stop that jump — otherwise
/// a spinner would do, and cost less.
///
/// So this is the real first screenful: the hero card with its figure and ring,
/// the row of shortcuts, and the four-figure money card. Everything below the
/// fold is left out, because a placeholder nobody scrolls to is a placeholder
/// that only costs frames.
///
/// ## It pulses
///
/// The blocks it replaced were static, which reads as content that has finished
/// loading and turned out to be blank. `AppSkeleton` fades between 45% and full
/// opacity — enough to say "still working" without a shimmer sweep's per-element
/// shader.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  /// The blocks, ready to splice into the screen's own list.
  ///
  /// Returned as a list rather than a column so they sit in the same `ListView`
  /// as the real content, under the same header — the header is real before the
  /// bills are, and replacing the whole screen with a placeholder would hide the
  /// one part that never needed loading.
  static List<Widget> blocks() => const <Widget>[
    _HeroSkeleton(),
    SizedBox(height: AppSpacing.sectionGap),
    _ActionsSkeleton(),
    SizedBox(height: AppSpacing.sectionGap),
    _MoneySkeleton(),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: blocks(),
  );
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // "TOTAL OUTSTANDING", then the figure at display size.
                    AppSkeleton(width: 132, height: 12),
                    SizedBox(height: AppSpacing.md),
                    AppSkeleton(width: 180, height: 34),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              AppSkeleton.circle(diameter: 96),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          AppSkeleton(width: 200, height: 12),
        ],
      ),
    );
  }
}

class _ActionsSkeleton extends StatelessWidget {
  const _ActionsSkeleton();

  /// Four, which is what a user with something outstanding sees. One too many is
  /// a smaller jump than one too few — the row's height is what matters and that
  /// does not change with the count.
  static const int _count = 4;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    // Scrolls sideways, exactly as the real row does. Four items on the same
    // 72dp grid come to 336 and a 320dp phone has 328 to give them, so a plain
    // Row overflows — which the responsive suite caught the moment the widths
    // were made to match. Matching the geometry means matching this too.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < _count; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.lg),
            // The real row gives each shortcut [DashboardQuickActions.itemWidth],
            // not the circle's own width. Packed tighter, every icon would slide
            // sideways the moment the data landed.
            SizedBox(
              width: DashboardQuickActions.itemWidth,
              child: Column(
                children: <Widget>[
                  // The real button is a white circle with a green icon in it, so
                  // the circle is drawn for real and only the icon stands in. That
                  // is both a truer placeholder and the way past the trap below —
                  // this row is the one part of the skeleton sitting on the canvas
                  // rather than on a card.
                  Container(
                    width: DashboardQuickActions.itemCircle,
                    height: DashboardQuickActions.itemCircle,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: AppSkeleton(width: 22, height: 22),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // `border`, not the default `surfaceMuted`. This label sits on
                  // the canvas, where muted is invisible — the whole row rendered
                  // as a gap, and the screen looked like it had loaded with a hole
                  // in it.
                  AppSkeleton(width: 48, height: 10, color: colors.border),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneySkeleton extends StatelessWidget {
  const _MoneySkeleton();

  @override
  Widget build(BuildContext context) {
    return const DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSkeleton(width: 96, height: 18),
          SizedBox(height: AppSpacing.lg),
          _FigurePairSkeleton(),
          SizedBox(height: AppSpacing.lg),
          _FigurePairSkeleton(),
        ],
      ),
    );
  }
}

class _FigurePairSkeleton extends StatelessWidget {
  const _FigurePairSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        Expanded(child: _FigureSkeleton()),
        SizedBox(width: AppSpacing.lg),
        Expanded(child: _FigureSkeleton()),
      ],
    );
  }
}

class _FigureSkeleton extends StatelessWidget {
  const _FigureSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The coloured dot and its label share a line.
        Row(
          children: <Widget>[
            AppSkeleton.circle(diameter: 8),
            SizedBox(width: AppSpacing.sm),
            AppSkeleton(width: 64, height: 12),
          ],
        ),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(width: 108, height: 22),
        SizedBox(height: AppSpacing.xs),
        AppSkeleton(width: 88, height: 10),
      ],
    );
  }
}
