import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_brand_mark.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';

/// The frame every authentication screen renders inside.
///
/// ## Why the three screens share one
///
/// They were three separate `Scaffold`s with `AppBar`s, and they drifted: sign-in
/// had cross-links, sign-up had none, and none of them had a working way back.
/// One frame means a change to the shape of the auth flow is one edit, and a
/// screen cannot quietly be the odd one out.
///
/// ## Why there is no AppBar
///
/// The reference design has none anywhere — its screens start with content and
/// carry their own header row. An `AppBar` also puts the screen's title in a
/// 20pt slot, which is the wrong weight for the first thing a new user reads.
/// The title here is a headline on the canvas, as the reference shows it.
///
/// ## Why the form sits on a card
///
/// The reference's language is a grey canvas with white sheets lifted off it.
/// The fields were previously flat on the canvas, which read as unfinished
/// rather than as minimal — there was nothing saying where the form began and
/// ended.
///
/// ## Back always goes somewhere
///
/// [backTo] is a route, not a `pop`. Sign-up is reached from the welcome screen
/// with `go`, which replaces the stack, so there was nothing to pop to and no
/// back button appeared at all — the user was stranded on sign-up with no way to
/// reach sign-in. Popping when there *is* a stack keeps a pushed screen feeling
/// pushed; falling back to a named route means the affordance is never absent.
class AuthScreenScaffold extends StatelessWidget {
  const AuthScreenScaffold({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.backTo,
    this.banner,
    this.footer,
    super.key,
  });

  /// The headline. What this screen is for, in two or three words.
  final String title;

  /// One line under it. Why the user is here, not a restatement of the title.
  final String subtitle;

  /// The fields and the primary action. Goes inside the card.
  final Widget form;

  /// Where back goes when there is no stack to pop.
  final AppRoutes backTo;

  /// Shown above the card — an error, or a confirmation.
  final Widget? banner;

  /// Links below the card. The way out of this screen that is not the primary
  /// action.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: AppContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenInset,
              AppSpacing.md,
              AppSpacing.screenInset,
              AppSpacing.xxxl,
            ),
            children: <Widget>[
              // One row, not two stacked. Separately they cost about 100dp of
              // header before the form even started, which pushed the submit
              // button below the fold on a short screen. The reference's screens
              // put their controls and their identity on a single top row for
              // the same reason.
              Row(
                children: <Widget>[
                  _BackButton(fallback: backTo),
                  const SizedBox(width: AppSpacing.md),
                  const AppBrandMark(),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                title,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.15,
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
              const SizedBox(height: AppSpacing.xxl),
              if (banner case final Widget message) ...<Widget>[
                message,
                const SizedBox(height: AppSpacing.lg),
              ],
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                borderRadius: AppRadii.panel,
                child: form,
              ),
              if (footer case final Widget links) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                links,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular ghost button, as the reference draws its icon buttons.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.fallback});

  final AppRoutes fallback;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            // Pop when there is somewhere to pop to, so a pushed screen behaves
            // like one. Otherwise go — which is the case that was broken.
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(fallback.routeName);
            }
          },
          child: SizedBox(
            // 44 rather than the 48 minimum: the icon is inset, and the Material
            // ink area is what gets tapped. Bumped to 48 by the SizedBox below on
            // purpose — see the constraint.
            width: 48,
            height: 48,
            child: Center(
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A centred link row, used under every auth card.
///
/// A row rather than two stacked `TextButton`s: the previous screens stacked
/// them, which put 96dp of near-identical green text under a form and made
/// neither look like the main way out.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    required this.leading,
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Plain text before the link — 'Already have an account?'.
  final String leading;

  /// The tappable part.
  final String label;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: Text(
            leading,
            textAlign: TextAlign.end,
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
