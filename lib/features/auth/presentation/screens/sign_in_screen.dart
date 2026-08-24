import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/validation/auth_validators.dart';
import '../controllers/sign_in_controller.dart';
import '../widgets/auth_screen_scaffold.dart';

/// Sign in.
///
/// Validation here is lighter than on registration by design. A sign-in form
/// checks that the fields are *filled*, not that the password meets today's
/// rules — an account created under older rules must still be able to get in,
/// and telling someone their existing password "needs a number" when it is
/// simply being typed wrong is actively misleading.
///
/// On success the screen pops. There is no auth gate until Sprint 15, so the
/// user returns to wherever they came from, with the account now visible on
/// Profile.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthenticatedUser?> state = ref.watch(
      signInControllerProvider,
    );

    // ref.listen rather than reacting inside build: navigating during a build is
    // an error, and a successful sign-in has to leave this screen.
    ref.listen<AsyncValue<AuthenticatedUser?>>(signInControllerProvider, (
      AsyncValue<AuthenticatedUser?>? previous,
      AsyncValue<AuthenticatedUser?> next,
    ) {
      if (next.value case final AuthenticatedUser user) {
        _onSignedIn(user);
      }
    });

    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isBusy = state.isLoading;

    return AuthScreenScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to pick up where you left off.',
      backTo: AppRoutes.welcome,
      banner: state.error == null
          ? null
          : AppInlineMessage(
              message: _messageFor(state.error!),
              tone: AppStatusTone.overdue,
              icon: Icons.error_outline_rounded,
            ),
      footer: AuthFooterLink(
        leading: 'No account yet?',
        label: 'Create one',
        onPressed: isBusy
            ? null
            : () => context.goNamed(AppRoutes.signUp.routeName),
      ),
      form: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !isBusy,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _password,
              label: 'Password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !isBusy,
              // Presence only — see the class comment.
              validator: (String? value) =>
                  (value ?? '').isEmpty ? 'Enter your password' : null,
              onFieldSubmitted: (_) => _submit(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
            // Sits with the password field rather than under the button, which
            // is where it belongs: it is a thing to do about the password, not
            // an alternative to signing in.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isBusy
                    ? null
                    : () =>
                          context.pushNamed(AppRoutes.forgotPassword.routeName),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: Text(
                  'Forgot your password?',
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            AppPrimaryButton(
              label: 'Sign in',
              isBusy: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    ref.read(signInControllerProvider.notifier).clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(signInControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  void _onSignedIn(AuthenticatedUser user) {
    final NavigatorState navigator = Navigator.of(context);

    showAppToast(
      context,
      message: 'Signed in as ${user.email}',
      tone: AppToastTone.success,
    );

    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// The backend's own words when they are fit to show, a generic line otherwise.
  static String _messageFor(Object error) => switch (error) {
    final AppException exception => exception.userMessage,
    _ => 'Something went wrong. Please try again.',
  };
}
