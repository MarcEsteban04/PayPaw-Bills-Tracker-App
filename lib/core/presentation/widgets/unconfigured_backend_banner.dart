import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../providers/supabase_providers.dart';

/// A strip across the top of the app saying the backend is not configured.
///
/// ## Why this exists
///
/// Without Supabase credentials the route guard deliberately does nothing —
/// guarding would trap the user on a sign-in screen that cannot work. The result
/// is an app that launches straight onto the dashboard, looks entirely normal,
/// and has no route to the auth screens at all.
///
/// That is correct behaviour and a terrible experience to debug. It cost two
/// rounds of "why is the dashboard showing" before this was written. The console
/// already carried [AppConfig.missingConfigMessage]; the problem is that nobody
/// reads a console when the app appears to have started fine.
///
/// ## Why a strip and not an overlay
///
/// It takes real space and pushes the app down, rather than floating over an app
/// bar and covering a title. A debug affordance that obscures the thing you are
/// looking at gets suppressed, and a suppressed warning is no warning.
///
/// The strip absorbs the status-bar inset itself and hands the app below a
/// zeroed top padding, so nothing ends up double-padded and no `SafeArea`
/// underneath fights it.
///
/// ## Debug only
///
/// A release build has its credentials compiled in or it does not work at all,
/// so there is nothing this could usefully tell a user — and it must never be
/// something they can see.
class UnconfiguredBackendBanner extends ConsumerWidget {
  const UnconfiguredBackendBanner({required this.child, super.key});

  final Widget child;

  /// Wraps [child]. Whether anything is actually shown is decided in [build].
  ///
  /// A release build never warns: its credentials are compiled in or it does not
  /// work at all, so there is nothing this could usefully tell a user — and it
  /// must never be something they can see.
  static Widget wrap(Widget child) =>
      kDebugMode ? UnconfiguredBackendBanner(child: child) : child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `isBackendConfiguredProvider`, not `AppConfig` directly. It is how the rest
    // of the app decides — and, more practically, a test that overrides it to
    // model a configured app must not then be handed a warning strip that shifts
    // every layout it is measuring. Reading AppConfig here broke two whole-app
    // tests for a reason that had nothing to do with what they were testing.
    if (ref.watch(isBackendConfiguredProvider)) {
      return child;
    }

    final MediaQueryData media = MediaQuery.of(context);

    return Column(
      children: <Widget>[
        _Strip(topInset: media.padding.top),
        Expanded(
          // The strip has already cleared the notch, so the app below must not
          // clear it a second time.
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(top: 0),
              viewPadding: media.viewPadding.copyWith(top: 0),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.topInset});

  final double topInset;

  @override
  Widget build(BuildContext context) {
    // Fixed colours rather than palette ones. This is not part of the design
    // system — it is a warning about the build, and it should look like it does
    // not belong.
    const Color background = Color(0xFFB91C1C);
    const Color foreground = Color(0xFFFFF1F1);

    final bool isSecretKey = AppConfig.hasSecretKeyMistake;

    return Material(
      color: background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isSecretKey
                        ? 'SECRET KEY IN CONFIG — Supabase not started'
                        : 'No Supabase config — sign-in and onboarding are off',
                    style: const TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSecretKey
                        // The one case where the fix is not "pass the file".
                        ? 'Use the publishable key (sb_publishable_…). '
                              'See docs/security.md.'
                        // Named exactly, because this is the thing to copy.
                        : 'Launch with: '
                              'flutter run --dart-define-from-file=config/dev.json',
                    style: const TextStyle(
                      color: foreground,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
