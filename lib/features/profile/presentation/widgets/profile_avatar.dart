import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../controllers/profile_providers.dart';

/// This account's face, or its initial.
///
/// ## One widget, because two screens draw it
///
/// The dashboard header and the settings screen both show this, and they must
/// not disagree about whose picture it is or what letter stands in for it. The
/// letter comes from [UserProfile.initialFor] for the same reason.
///
/// ## The initial is the ground state, not a placeholder
///
/// It shows while the URL is being minted, when there is no picture, and when a
/// picture fails to load — three different reasons for the same honest answer.
/// A spinner would flash on every launch for a photograph that is usually
/// cached, and a broken-image glyph would report a problem the user cannot fix.
class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    required this.size,
    this.onTap,
    this.showEditBadge = false,
    super.key,
  });

  final double size;

  /// Tapping it. Null where the avatar is decoration rather than a control.
  final VoidCallback? onTap;

  /// Whether to mark it as the way to change the picture.
  ///
  /// Off by default, and that is the point: the dashboard's avatar is tappable
  /// too, but it opens Settings. A camera badge there would advertise an action
  /// the tap does not perform — which is worse than no affordance, because the
  /// user learns the badge means nothing.
  ///
  /// It also decides the spoken label, for the same reason.
  final bool showEditBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;

    final String? name = ref.watch(displayNameProvider);
    final String? email = ref.watch(currentUserProvider).value?.email;
    final String? url = ref.watch(avatarUrlProvider).value;

    final Widget circle = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: colors.primarySoft,
          child: url == null
              ? _Initial(
                  letter: UserProfile.initialFor(name: name, email: email),
                  size: size,
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  // Back to the initial rather than a broken-image glyph. A
                  // signed URL can expire mid-session and the object can be
                  // gone; neither is something the reader can act on.
                  errorBuilder: (_, _, _) => _Initial(
                    letter: UserProfile.initialFor(name: name, email: email),
                    size: size,
                  ),
                ),
        ),
      ),
    );

    if (onTap == null) {
      return circle;
    }

    final Widget tappable = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: circle),
    );

    // No badge and no label of its own: the caller says what its tap does, and
    // here it does not change the picture.
    if (!showEditBadge) {
      return tappable;
    }

    return Semantics(
      button: true,
      label: url == null
          ? 'Add a profile picture'
          : 'Change your profile picture',
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          tappable,
          // A camera badge, because a circular photograph does not look
          // tappable. Outside the InkWell so it cannot swallow the tap it is
          // advertising.
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: size * 0.22,
                color: colors.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.letter, required this.size});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          // Scaled to the circle rather than taken from the text theme, so the
          // same widget reads correctly at 40dp in a header and 72dp on the
          // settings screen.
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: context.colors.primaryText,
          height: 1,
        ),
      ),
    );
  }
}
