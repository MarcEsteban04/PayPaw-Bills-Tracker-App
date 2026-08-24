import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_brand_mark.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/onboarding_providers.dart';

/// The first thing a new install shows.
///
/// ## The mistake this version fixes
///
/// The first version made the whole screen black, because the illustration it
/// used is drawn on black. That worked, and it was still wrong: the rest of
/// PayPaw is a light app, so the very first tap flipped the theme and the two
/// screens read as different products.
///
/// The fix went through a dark card on the light canvas before arriving at the
/// obvious answer: use the asset that does not need one. The logo is the same
/// mascot with the same wallet, calendar and bell, and it has a genuinely
/// transparent background — so it sits on the canvas with no surface behind it at
/// all. The illustration is kept at
/// `design/source/welcome_illustration_on_black.png` and no longer ships.
///
/// Its background could not simply be removed: measuring the file showed only 31%
/// of the frame is near-black and the glow reaches the edges, so it is a gradient
/// rather than a key colour. Any threshold leaves a hard ring or a gold haze, and
/// the mascot's own dark outlines make luminance keying worse still.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Ceiling on the art's height, as a share of the viewport.
  ///
  /// Deliberately modest. The logo is the mascot, not a hero image: at 45% it
  /// dominated the screen and pushed the words away from it, which is half of why
  /// the group looked split apart.
  static const double _maxArtFraction = 0.34;

  /// The logo's inset from the sides, which also bounds how wide it can be.
  static const double _heroInset = AppSpacing.lg;

  /// Roughly what the words and buttons occupy at normal text size.
  ///
  /// A hint, not a contract — see the comment in `build`. It exists so a short
  /// screen shrinks the art instead of pushing the buttons below the fold; being
  /// twenty points out in either direction costs nothing.
  static const double _wordsHint = 460;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: AppContentWidth(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // ## Why this is not a reserved height any more
              //
              // The first three versions gave the words a measured reserve in
              // logical pixels and handed the art the remainder. It never
              // settled: 380 put the sign-in link below the fold, 430 was a point
              // and a half short on a narrow screen, 448 was nineteen points
              // short once a brand row was added, and 476 still left a strip of
              // dead space on the emulator. A constant that has to equal the
              // height of a paragraph of wrapping text is a constant that is
              // wrong on the next screen size.
              //
              // So nothing measures text now. The art is a **square** — as tall
              // as the card is wide — capped on short screens, and the framework
              // is asked for the words' height instead of being told it.
              final double textScale =
                  MediaQuery.textScalerOf(context).scale(16) / 16;
              final double cardWidth = constraints.maxWidth - _heroInset * 2;

              // Three ceilings, smallest wins. The last one is a rough hint at
              // what the words need — and unlike the reserve this replaced, it no
              // longer has to be right. Too generous and the `Spacer` above
              // absorbs the slack; too mean and the column scrolls a little.
              // Nothing clips and nothing leaves a hole either way, which is the
              // whole point of moving the anchoring into the layout instead of
              // deriving it from a constant.
              final double artHeight = math.min(
                math.min(cardWidth, constraints.maxHeight * _maxArtFraction),
                math.max(0, constraints.maxHeight - _wordsHint * textScale),
              );

              // The logo, the words and the buttons are **one group, centred**.
              //
              // Two earlier attempts split them: art at the top and words pushed
              // to the bottom, with the leftover space in between. Both left an
              // obvious hole in the middle of the screen — first under the
              // buttons, then above the headline. There is nothing between the
              // mascot and the headline that wants separating; they are one piece
              // of content and belong together.
              //
              // IntrinsicHeight is what allows the centring. Inside a scroll view
              // the column's height is unbounded, so `mainAxisAlignment` would
              // have nothing to distribute; IntrinsicHeight gives it a definite
              // height, and the ConstrainedBox raises that to the viewport when
              // the group is shorter. Taller — at large text sizes — and it
              // simply scrolls.
              //
              // It costs one extra layout pass over a tree of five widgets.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _WelcomeHero(height: artHeight),
                        _WelcomeContent(
                          onGetStarted: () =>
                              _leave(context, ref, AppRoutes.signUp),
                          onSignIn: () =>
                              _leave(context, ref, AppRoutes.signIn),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Marks the screen seen and goes where the user asked.
  ///
  /// Recorded on the way out rather than on the way in, so an install killed on
  /// this screen sees it again — the friendlier of the two mistakes.
  void _leave(BuildContext context, WidgetRef ref, AppRoutes destination) {
    // Fire and forget: the navigation should not wait on a disk write, and a
    // failed write costs one extra welcome screen.
    ref.read(onboardingProgressStoreProvider).markWelcomeSeen();

    context.goNamed(destination.routeName);
  }
}

/// The logo, centred on the canvas.
///
/// No card and no dark surface. The previous version sat the mascot on a black
/// panel because the illustration it used was *drawn* on black, and that panel
/// was the only thing making it work on a light screen. The logo has a genuinely
/// transparent background, so the mascot can sit on the canvas directly — which
/// is what a welcome screen should look like, and one fewer surface to explain.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    // At large text on a small screen there is no room left. Dropped rather than
    // sized to zero: `Image` asserts on a `cacheHeight` of 0, and decoding an
    // image nobody can see would be waste even if it did not.
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      // No top inset: the column centres the whole group, so spacing above the
      // logo is not this widget's business.
      padding: EdgeInsets.zero,
      child: Center(
        child: AppBrandMark(
          size: height,
          // The headline underneath says the app's name, and the logo is already
          // the largest thing on the screen. Printing "PayPaw" over it as well
          // would be saying it three times.
          showName: false,
        ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.onGetStarted, required this.onSignIn});

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      // Tight to the logo above it. These are one group, and 24dp of air between
      // the mascot and the headline was enough to make them read as two.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'PayPaw',
            style: textTheme.labelLarge?.copyWith(
              color: colors.primaryText,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stay ahead of\nwhat you owe.',
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Bills, subscriptions and utang in one place — '
            'with a reminder before the due date, not after it.',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          // The app's own primary button now that the screen is light. The lime
          // variant this used to carry existed only because the background was
          // black; on the canvas the brand green is simply correct, and one fewer
          // one-off button is worth having.
          AppPrimaryButton(label: 'Get started', onPressed: onGetStarted),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: onSignIn,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                'I already have an account',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
