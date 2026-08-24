import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/app_assets.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/onboarding_providers.dart';

/// The first thing a new install shows.
///
/// ## The mistake this version fixes
///
/// The first version made the whole screen black, because the illustration is
/// drawn on black and letterboxing it against a black scaffold hides the fact
/// that the image is never cropped. That worked, and it was still wrong: the rest
/// of PayPaw is a light app, so the very first tap flipped the theme and the two
/// screens read as different products.
///
/// The art now sits in a **dark rounded card on the light canvas** — the
/// reference design's own language of a grey ground with sheets lifted off it.
/// The letterboxing still disappears, because it happens inside a surface that is
/// meant to be dark. Nothing is cropped, nothing flips, and the card is the same
/// shape as every card the user meets afterwards.
///
/// ## Why the art is `contain`, not `cover`
///
/// The illustration is 2:3 and a phone is nearer 1:2. `cover` would crop roughly
/// a third of the width — losing the calendar on one side and the wallet on the
/// other, which are the details that say "bills" rather than "cute dog".
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Ceiling on the art's height, as a share of the viewport.
  ///
  /// The art is otherwise as tall as the card is wide — a square, which is a
  /// shape rather than a number and cannot be a few points wrong. This caps it on
  /// a short screen so the words always get their half.
  static const double _maxArtFraction = 0.45;

  /// The hero card's inset from the sides and the top.
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

              // IntrinsicHeight is what makes `Spacer` work here. Inside a scroll
              // view the column's height is unbounded, so a flexible child would
              // throw; IntrinsicHeight gives it a definite height, and the
              // ConstrainedBox raises that to the viewport when the content is
              // shorter. Slack then lands between the art and the words, and the
              // buttons sit at the bottom where they belong.
              //
              // It costs an extra layout pass over a tree of six widgets.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: <Widget>[
                        _WelcomeHero(height: artHeight),
                        // Collapses to nothing when the words need the room — at
                        // large text sizes the whole column simply scrolls.
                        const Spacer(),
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

/// The illustration, in a dark card on the light canvas.
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.height});

  final double height;

  /// The card's own black. Taken from the artwork rather than from the palette,
  /// because its only job is to match the image's background exactly — the moment
  /// it does not, a rectangle appears around the mascot.
  static const Color artBackground = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    // At large text on a small screen the reserve takes the whole viewport and
    // there is no room left. Dropped rather than sized to zero: `Image` asserts
    // on a `cacheHeight` of 0, and decoding an image nobody can see would be
    // waste even if it did not.
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.panel,
        child: ColoredBox(
          color: artBackground,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Image.asset(
              AppAssets.welcomeIllustration,
              fit: BoxFit.contain,
              // Bottom-aligned so the mascot sits on the card's lower edge rather
              // than floating with a gap beneath it.
              alignment: Alignment.bottomCenter,
              // A 1.6 MB PNG decoded at full size is ~6 MB of RAM for something
              // never drawn larger than the card.
              cacheHeight: (height * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              // Decoration, not information: the headline below says everything a
              // screen reader needs, and announcing the image would add noise
              // ahead of the two buttons that matter.
              excludeFromSemantics: true,
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _BrandRow(),
          const SizedBox(height: AppSpacing.md),
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

/// The paw and the name, matching the mark on the auth screens so the flow reads
/// as one product.
class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.pets_rounded,
              size: 14,
              color: colors.textOnPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'PayPaw',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.primaryText,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
