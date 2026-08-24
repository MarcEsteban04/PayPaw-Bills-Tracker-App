import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/app_assets.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/onboarding_providers.dart';

/// The first thing a new install shows.
///
/// ## Why this screen is dark in both themes
///
/// The illustration is drawn on black, with the glow around the mascot fading
/// into it. There is no light version of it, and no amount of theming produces
/// one — so the screen commits to dark rather than putting a black-backed image
/// on a light canvas with a visible seam around it. It is the one screen in
/// PayPaw that ignores the theme, and it does so because the art decides.
///
/// ## Why the art is `contain`, not `cover`
///
/// The illustration is 2:3. A phone is nearer 1:2, so `cover` would crop roughly
/// a third of the width — losing the calendar on one side and the wallet on the
/// other, which are the details that say "bills" rather than "cute dog".
/// `contain` never crops, and the letterboxing it produces is *invisible*
/// because the image's own background is the same black as the scaffold. That
/// only works here, and it is the whole reason this layout is possible.
///
/// ## Why the content sits below the art
///
/// The mascot is bottom-weighted, so the composition already reads top-to-bottom.
/// Text over the lower third would need a scrim across the wallet and the
/// checklist; text underneath needs nothing covered at all.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  /// Room the words and buttons need at normal text size, measured.
  ///
  /// The art gets what is left over, rather than a fixed share of the screen.
  /// A share cannot work: 56% leaves plenty on a 830pt phone and pushes the
  /// buttons off a 568pt one, and a welcome screen whose only two controls are
  /// below the fold is a welcome screen that fails silently.
  ///
  /// Scaled by the text scale factor, so the reserve grows with the text it is
  /// reserving room for. The figure is measured, not guessed: a widget test
  /// asserts both actions land inside the viewport at normal text size, on the
  /// smallest and the most common screen. An earlier 380 put the sign-in link
  /// twelve points below the fold on an ordinary phone, and 430 left it a point
  /// and a half short on the narrowest one, where the subheading wraps to an
  /// extra line.
  static const double _contentReserve = 448;

  /// Ceiling on the art's share, so it does not dominate a tall screen.
  static const double _maxArtFraction = 0.6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The screen paints its own ground, so the app's canvas gradient does not
    // show through around the letterboxed image.
    const Color background = Color(0xFF000000);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons: the bar sits on black here whatever the theme is.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double textScale =
                MediaQuery.textScalerOf(context).scale(16) / 16;

            // What is left after the words, never more than a share of the
            // screen and never negative. At large text on a small phone this
            // reaches zero and the art disappears — which is the right
            // priority: decoration yields to the two buttons.
            final double artHeight =
                (constraints.maxHeight - _contentReserve * textScale).clamp(
                  0.0,
                  constraints.maxHeight * _maxArtFraction,
                );

            // Scrollable rather than flexible: at large text sizes the content
            // block genuinely does not fit, and scrolling black is a far better
            // failure than an overflow stripe or clipped buttons.
            return SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  _WelcomeArt(height: artHeight),
                  AppContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        AppSpacing.xl,
                        AppSpacing.xxl,
                        AppSpacing.xxl,
                      ),
                      child: _WelcomeContent(
                        onGetStarted: () =>
                            _leave(context, ref, AppRoutes.signUp),
                        onSignIn: () => _leave(context, ref, AppRoutes.signIn),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Marks the screen seen and goes where the user asked.
  ///
  /// Recorded on the way out rather than on the way in, so an install that is
  /// killed on this screen sees it again — which is the friendlier of the two
  /// mistakes.
  void _leave(BuildContext context, WidgetRef ref, AppRoutes destination) {
    // Fire and forget: the navigation should not wait on a disk write, and a
    // failed write costs one extra welcome screen.
    ref.read(onboardingProgressStoreProvider).markWelcomeSeen();

    context.goNamed(destination.routeName);
  }
}

/// The illustration, letterboxed into the top of the screen.
class _WelcomeArt extends StatelessWidget {
  const _WelcomeArt({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    // At large text on a small screen the reserve consumes the whole viewport
    // and there is no room left. Dropping the widget rather than sizing it to
    // zero: `Image` asserts on a `cacheHeight` of 0, and decoding an image
    // nobody can see would be waste even if it did not.
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(
        AppAssets.welcomeIllustration,
        fit: BoxFit.contain,
        // Bottom-aligned so the mascot sits directly above the text rather than
        // floating with a gap under it. Any spare room goes to the top, where the
        // artwork is empty black anyway.
        alignment: Alignment.bottomCenter,
        // A 1.6 MB PNG decoded at full size is ~6 MB of RAM for something never
        // shown larger than the screen. Capping the decode cuts that to what is
        // actually drawn.
        cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
        // The mascot is decoration, not information: the headline underneath says
        // everything a screen reader needs. Announcing it would add noise ahead
        // of the two buttons that matter.
        excludeFromSemantics: true,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'PayPaw',
          style: textTheme.labelLarge?.copyWith(
            color: colors.navActivePill,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Stay ahead of\nwhat you owe.',
          style: textTheme.displaySmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Bills, subscriptions and utang in one place — '
          'with a reminder before the due date, not after it.',
          style: textTheme.bodyMedium?.copyWith(
            // Not pure white: a subhead at full brightness competes with the
            // headline it is meant to support.
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _WelcomePrimaryButton(label: 'Get started', onPressed: onGetStarted),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('I already have an account'),
          ),
        ),
      ],
    );
  }
}

/// The primary action, in the palette's dark-surface accent.
///
/// Not `AppPrimaryButton`: that one is the brand green, which is tuned for a
/// light card and goes muddy on black. `navActivePill` is the lime the navigation
/// bar already uses to mean "this is the live thing" — it is the palette's own
/// answer for an accent on a dark surface, so using it here is consistent by
/// construction rather than a one-off. It also happens to echo the gold glow in
/// the illustration, and dark text on it clears WCAG AA comfortably.
class _WelcomePrimaryButton extends StatelessWidget {
  const _WelcomePrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.navActivePill,
          foregroundColor: colors.navOnActivePill,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}
