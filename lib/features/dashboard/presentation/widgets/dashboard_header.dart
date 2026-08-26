import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../profile/presentation/widgets/profile_avatar.dart';

/// Who is looking, and roughly when.
///
/// The reference design's header is "Welcome Back 👋" over a name, with an avatar
/// on the right, and that is what this is now: the profile carries a real name
/// and a real picture. Both have fallbacks that are visibly fallbacks — the local
/// part of the address, and the initial of it — because most accounts have given
/// neither.
///
/// **The greeting is the one place the device clock is the right source.** Every
/// date in this app comes from the database, because a phone with the wrong date
/// would disagree with the statuses on the same screen. "Good evening" has no such
/// obligation: it is about the person holding the phone, not about a bill.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.email,
    required this.now,
    this.name,
    this.onAvatarPressed,
    super.key,
  });

  /// What this person calls themselves, from their profile. Null until they
  /// have said, which is most accounts and every new one.
  final String? name;

  /// Null while the session is still resolving, which is a moment, not a state
  /// worth designing for — the greeting stands on its own until it arrives.
  final String? email;

  /// Passed in rather than read here, so a test is not at the mercy of the hour
  /// it runs at.
  final DateTime now;

  final VoidCallback? onAvatarPressed;

  static const double _avatarSize = 48;

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
                nameOrAddress(name: name, email: email),
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
        // The same widget the settings screen draws, so the picture and the
        // letter that stands in for it cannot differ between the two places
        // somebody sees their own face.
        Semantics(
          button: onAvatarPressed != null,
          label: 'Settings',
          child: ProfileAvatar(size: _avatarSize, onTap: onAvatarPressed),
        ),
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

  /// What to call this person in the heading.
  ///
  /// Their name if they have given one, and the local part of their address if
  /// not. The address is a *fallback*, not a name — "marcdelacruzesteban" is a
  /// login, and it was the only thing PayPaw had to greet anybody with until
  /// there was a profile to carry the real one.
  ///
  /// Not the whole address either way: a header is an identity, not a
  /// credential, and "marc@gmail.com" wrapping across two lines reads as a form
  /// field.
  static String nameOrAddress({String? name, String? email}) {
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }

    if (email == null || email.isEmpty) {
      return 'Welcome back';
    }

    final String local = email.split('@').first;

    return local.isEmpty ? 'Welcome back' : local;
  }
}
