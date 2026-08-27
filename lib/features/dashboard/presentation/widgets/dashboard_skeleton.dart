import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/dashboard_mood.dart';
import 'dashboard_cards.dart';
import 'dashboard_hero_body.dart';
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
    // Shaped like the real hero, mascot and all.
    //
    // The mascot is decoration rather than data — it stands in for nothing, so
    // there is nothing to fake — but the hero's height is derived from its width
    // and the mascot is what makes it that tall. A placeholder card of some other
    // height would drop the whole screen when the bills land, which is the jump
    // a skeleton exists to prevent.
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: DashboardHeroBody(
        mood: DashboardMood.noneSettled,
        ring: (double diameter) => AppSkeleton.circle(diameter: diameter),
        footnote: const AppSkeleton(width: 160, height: 12),
        figures: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // "TOTAL OUTSTANDING", then the figure at display size.
            AppSkeleton(width: 132, height: 12),
            SizedBox(height: AppSpacing.md),
            AppSkeleton(width: 140, height: 34),
          ],
        ),
      ),
    );
  }
}

class _ActionsSkeleton extends StatelessWidget {
  const _ActionsSkeleton();

  /// Two actions, which is what a user with something outstanding sees. One too
  /// many is a smaller jump than one too few — what matters is the block's
  /// height, and that does not change with the count.
  static const int _actionCount = 2;

  /// Three destinations, which never varies.
  static const int _destinationCount = 3;

  @override
  Widget build(BuildContext context) {
    // The real block's own geometry, so nothing moves when the data lands. Both
    // rows divide the width they are given, so this needs no widths of its own —
    // only the heights and the gap.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SkeletonRow(
          count: _actionCount,
          height: DashboardQuickActions.actionHeight,
        ),
        const SizedBox(height: AppSpacing.cardGap),
        _SkeletonRow(
          count: _destinationCount,
          height: DashboardQuickActions.destinationHeight,
        ),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Row(
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            // The real tile is a filled surface with content inside it, so the
            // surface is drawn for real and only the content stands in. That is
            // both a truer placeholder and the way past the trap below — this
            // block is the one part of the skeleton sitting on the canvas rather
            // than on a card.
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.card,
              ),
              alignment: Alignment.center,
              // `border`, not the default `surfaceMuted`, which is invisible
              // against this surface — the whole block rendered as a gap, and the
              // screen looked like it had loaded with a hole in it.
              child: AppSkeleton(width: 48, height: 10, color: colors.border),
            ),
          ),
        ],
      ],
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
