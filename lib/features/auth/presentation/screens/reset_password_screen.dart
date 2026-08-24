import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/validation/auth_validators.dart';
import '../controllers/reset_password_controller.dart';
import '../widgets/password_requirements_list.dart';

/// Sets a new password, using the recovery session created by a reset link.
///
/// Reached automatically when a reset link is opened — not from a menu. Opening
/// it any other way leaves no recovery session, and the save fails with a message
/// saying the link expired, which is accurate.
///
/// The same password rules as registration apply, from the same validators.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _onPasswordChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthenticatedUser?> state = ref.watch(
      resetPasswordControllerProvider,
    );

    ref.listen<AsyncValue<AuthenticatedUser?>>(
      resetPasswordControllerProvider,
      (
        AsyncValue<AuthenticatedUser?>? previous,
        AsyncValue<AuthenticatedUser?> next,
      ) {
        if (next.value != null) {
          _onPasswordChangedSuccessfully();
        }
      },
    );

    final bool isBusy = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenInset,
            0,
            AppSpacing.screenInset,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            Text(
              'Choose a new password for your account.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            if (state.error case final Object error) ...<Widget>[
              AppInlineMessage(
                message: _messageFor(error),
                tone: AppStatusTone.overdue,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            AppTextField(
              controller: _password,
              label: 'New password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              enabled: !isBusy,
              validator: AuthValidators.password,
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
            const SizedBox(height: AppSpacing.sm),
            PasswordRequirementsList(password: _password.text),
            const SizedBox(height: AppSpacing.lg),

            AppTextField(
              controller: _confirmation,
              label: 'Confirm new password',
              obscureText: true,
              textInputAction: TextInputAction.done,
              enabled: !isBusy,
              validator: (String? value) =>
                  AuthValidators.passwordConfirmation(value, _password.text),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            AppPrimaryButton(
              label: 'Save new password',
              isBusy: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    ref.read(resetPasswordControllerProvider.notifier).clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(password: _password.text);
  }

  void _onPasswordChangedSuccessfully() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Password updated. You are signed in.')),
      );

    // go, not pop: this screen is usually the first thing on the stack, because
    // the reset link launched the app. There may be nothing behind it.
    context.goNamed(AppRoutes.dashboard.routeName);
  }

  static String _messageFor(Object error) => switch (error) {
    final AppException exception => exception.userMessage,
    _ => 'Something went wrong. Please try again.',
  };
}
