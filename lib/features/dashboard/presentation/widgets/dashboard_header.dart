import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';

/// Who is looking, and roughly when.
///
/// The reference design's header is "Welcome Back 👋" over a name, with an avatar
/// on the right. PayPaw has an email and no display name — Sprint 54 adds the
/// profile that would carry one — so the greeting does the work the name would
/// have, and the avatar is an initial rather than a photo.
///
/// **The greeting is the one place the device clock is the right source.** Every
/// date in this app comes from the database, because a phone with the wrong date
/// would disagree with the statuses on the same screen. "Good evening" has no such
/// obligation: it is about the person holding the phone, not about a bill.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.email,
    required this.now,
    this.onAvatarPressed,
    super.key,
  });

  /// Null while the session is still resolving, which is a moment, not a state
  /// worth designing for — the greeting stands on its own until it arrives.
  final String? email;

  /// Passed in rather than read here, so a test is not at the mercy of the hour
  /// it runs at.
  final DateTime now;

  final VoidCallback? onAvatarPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                greeting(now),
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                // The local part of the address. Not the whole thing: a header is
                // an identity, not a credential, and "marc@gmail.com" wrapping
                // across two lines reads as a form field.
                displayName(email),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _Avatar(initial: initial(email), onPressed: onAvatarPressed),
      ],
    );
  }

  /// 'Good morning' / 'Good afternoon' / 'Good evening'.
  ///
  /// Boundaries at noon and 18:00 — the usual ones. Anything before 05:00 is
  /// still evening rather than morning, because somebody up at three has not
  /// started their day.
  static String greeting(DateTime now) => switch (now.hour) {
    >= 5 && < 12 => 'Good morning',
    >= 12 && < 18 => 'Good afternoon',
    _ => 'Good evening',
  };

  /// The part of an address before the '@', or a fallback.
  static String displayName(String? email) {
    if (email == null || email.isEmpty) {
      return 'Welcome back';
    }

    final String local = email.split('@').first;

    return local.isEmpty ? 'Welcome back' : local;
  }

  static String initial(String? email) {
    final String name = displayName(email);

    return name.substring(0, 1).toUpperCase();
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onPressed});

  final String initial;
  final VoidCallback? onPressed;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      button: onPressed != null,
      label: 'Profile',
      child: Material(
        color: colors.primarySoft,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Center(
              child: Text(
                initial,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
