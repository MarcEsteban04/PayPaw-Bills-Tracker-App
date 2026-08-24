import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/authenticated_user.dart';
import '../controllers/current_user_provider.dart';
import '../controllers/sign_out_controller.dart';

/// The account section of the Profile screen.
///
/// Three states, and the third one matters: an app with no Supabase
/// configuration is not "signed out", it is *unable to sign in*, and offering a
/// sign-in button that can only fail is worse than saying so.
///
/// Signing out confirms first. It is not destructive, but it is disruptive, and
/// one stray tap away from a re-authentication nobody wanted.
class AccountSummary extends ConsumerWidget {
  const AccountSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthenticatedUser?> user = ref.watch(currentUserProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Account', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (!ref.watch(isBackendConfiguredProvider))
          const AppInlineMessage(
            message:
                'No backend configured, so signing in is not possible yet. '
                'See docs/supabase_setup.md.',
            tone: AppStatusTone.info,
            icon: Icons.info_outline_rounded,
          )
        else
          switch (user) {
            AsyncData<AuthenticatedUser?>(value: final AuthenticatedUser it) =>
              _SignedIn(user: it),
            AsyncError<AuthenticatedUser?>() => const AppInlineMessage(
              message: 'Could not check your sign-in status.',
              tone: AppStatusTone.overdue,
              icon: Icons.error_outline_rounded,
            ),
            // Loading and signed-out both offer the same actions. A brief
            // loading state that flashed a spinner here would be more
            // distracting than useful.
            _ => const _SignedOut(),
          },
      ],
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSigningOut = ref.watch(signOutControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _AccountCard(user: user),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          isBusy: isSigningOut,
          onPressed: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }

  /// Confirms first. Signing out is not destructive, but it is disruptive and
  /// one stray tap away from a re-authentication the user did not want.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Sign out?',
      message:
          'You will need to sign in again on this device. Your bills stay where '
          'they are.',
      confirmLabel: 'Sign out',
    );

    if (confirmed) {
      await ref.read(signOutControllerProvider.notifier).signOut();
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AuthenticatedUser user;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.colors;

    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(
            Icons.account_circle_rounded,
            size: 36,
            color: palette.primaryText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                if (user.hasConfirmedEmail)
                  const AppStatusChip(
                    label: 'Signed in',
                    tone: AppStatusTone.paid,
                  )
                else
                  const AppStatusChip(
                    label: 'Email not confirmed',
                    tone: AppStatusTone.dueSoon,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPrimaryButton(
          label: 'Sign in',
          onPressed: () => context.pushNamed(AppRoutes.signIn.routeName),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Create account',
          onPressed: () => context.pushNamed(AppRoutes.signUp.routeName),
        ),
      ],
    );
  }
}
