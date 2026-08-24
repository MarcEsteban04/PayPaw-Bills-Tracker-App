import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validation/auth_validators.dart';
import '../controllers/forgot_password_controller.dart';
import '../widgets/auth_screen_scaffold.dart';

/// Requests a password reset email.
///
/// The confirmation is worded carefully: **"if that address has an account"**.
/// Supabase succeeds whether or not the user exists, deliberately, because an
/// endpoint that answers "no such user" is a way to find out who is registered
/// here. Saying "we sent you an email" outright would leak the same thing the
/// backend is withholding.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<String?> state = ref.watch(
      forgotPasswordControllerProvider,
    );

    if (state case AsyncData<String?>(value: final String email)) {
      return Scaffold(
        body: SafeArea(child: _Sent(email: email)),
      );
    }

    final bool isBusy = state.isLoading;

    return AuthScreenScaffold(
      title: 'Reset your password',
      // The explanation belongs here rather than as the first line of the form:
      // it is context for the whole screen, not a label for the field.
      subtitle:
          'Enter the email on your account and we will send you a link to set '
          'a new password.',
      backTo: AppRoutes.signIn,
      banner: state.error == null
          ? null
          : AppInlineMessage(
              message: _messageFor(state.error!),
              tone: AppStatusTone.overdue,
              icon: Icons.error_outline_rounded,
            ),
      footer: AuthFooterLink(
        leading: 'Remembered it?',
        label: 'Back to sign in',
        onPressed: isBusy
            ? null
            : () => context.goNamed(AppRoutes.signIn.routeName),
      ),
      form: _buildForm(isBusy: isBusy),
    );
  }

  Widget _buildForm({required bool isBusy}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _email,
            label: 'Email',
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !isBusy,
            validator: AuthValidators.email,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          AppPrimaryButton(
            label: 'Send reset link',
            isBusy: isBusy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    ref.read(forgotPasswordControllerProvider.notifier).clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(email: _email.text);
  }

  static String _messageFor(Object error) => switch (error) {
    final AppException exception => exception.userMessage,
    _ => 'Something went wrong. Please try again.',
  };
}

/// Shown once the request has gone through.
class _Sent extends StatelessWidget {
  const _Sent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AppStateMessage(
      icon: Icons.mark_email_read_outlined,
      title: 'Check your email',
      // "If that address has an account" — see the class comment. This wording
      // is the privacy behaviour, not hedging.
      message:
          'If $email has an account, a link to set a new password is on its '
          'way. Open it on this device so PayPaw can finish the reset.',
    );
  }
}
