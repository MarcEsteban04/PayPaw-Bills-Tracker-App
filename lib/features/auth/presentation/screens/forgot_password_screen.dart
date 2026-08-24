import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validation/auth_validators.dart';
import '../controllers/forgot_password_controller.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: switch (state) {
        AsyncData<String?>(value: final String email) => _Sent(email: email),
        _ => _buildForm(state),
      },
    );
  }

  Widget _buildForm(AsyncValue<String?> state) {
    final bool isBusy = state.isLoading;

    return Form(
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
            'Enter the email address on your account and we will send you a '
            'link to set a new password.',
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
