import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/domain/entities/authenticated_user.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../domain/entities/user_profile.dart';
import '../controllers/profile_providers.dart';
import 'edit_display_name_sheet.dart';

/// Who this is, at the top of the screen.
///
/// ## Why the name is the headline and the address is not
///
/// PayPaw greeted people as "marcdelacruzesteban" for forty sprints, because an
/// email local-part was the only name it had. That is not a name anybody chose —
/// it is a login. The card leads with what they *did* choose, and keeps the
/// address underneath as the thing that identifies the account.
///
/// Without a name it says so and invites one, rather than silently falling back
/// to the address in the large type. An empty state that asks for something is
/// worth more than one that quietly makes do.
class ProfileIdentityCard extends ConsumerWidget {
  const ProfileIdentityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AuthenticatedUser? user = ref.watch(currentUserProvider).value;
    final UserProfile? profile = ref.watch(userProfileProvider).value;

    final String? name = profile?.name;
    final String? email = user?.email;

    return Material(
      color: colors.surface,
      borderRadius: AppRadii.panel,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Tappable whether or not there is a name yet: with one it edits, and
        // without one it is the only invitation on the screen to add it.
        onTap: () => showEditDisplayNameSheet(context: context, name: name),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardInset),
          decoration: BoxDecoration(
            borderRadius: AppRadii.panel,
            border: colors.surfaceBorder,
          ),
          child: Row(
            children: <Widget>[
              _Avatar(
                initial: UserProfile.initialFor(name: name, email: email),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name ?? 'Add your name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        // Dimmed when it is a prompt rather than a fact, so the
                        // line does not read as somebody actually called "Add
                        // your name".
                        color: name == null
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      email ?? 'Not signed in',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.edit_outlined, size: 20, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// An initial in a circle.
///
/// Not a photograph. `profiles.avatar_url` has been in the schema since
/// migration 0002 and there is nowhere to upload one to until Storage lands in
/// Sprint 57 — a picker that could only fail is worse than an initial.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});

  final String initial;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: colors.primaryText, fontWeight: FontWeight.w700),
      ),
    );
  }
}
