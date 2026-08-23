import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_state_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/sign_up_outcome.dart';
import '../../domain/validation/auth_validators.dart';
import '../controllers/sign_up_controller.dart';
import '../widgets/password_requirements_list.dart';

/// Registration.
///
/// The form validates on the client first so an obvious typo does not cost a
/// round trip, and then again on the backend, whose rejection is shown inline
/// rather than replacing the screen — the user needs to see what they typed in
/// order to fix it.
///
/// On success the form is replaced by a confirmation message, because with email
/// confirmation on the account exists but the user is **not** signed in. Sending
/// them onward to a dashboard would show them an app that cannot load anything.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    // The requirements checklist has to update as the user types.
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _onPasswordChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SignUpOutcome?> state = ref.watch(
      signUpControllerProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: switch (state) {
        AsyncData<SignUpOutcome?>(value: final SignUpOutcome outcome) =>
          _Confirmation(outcome: outcome),
        _ => _buildForm(state),
      },
    );
  }

  Widget _buildForm(AsyncValue<SignUpOutcome?> state) {
    final TextTheme textTheme = Theme.of(context).textTheme;
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
          Text('Track every bill in one place.', style: textTheme.bodyLarge),
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
            textInputAction: TextInputAction.next,
            enabled: !isBusy,
            validator: AuthValidators.email,
          ),
          const SizedBox(height: AppSpacing.lg),

          AppTextField(
            controller: _password,
            label: 'Password',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            enabled: !isBusy,
            validator: AuthValidators.password,
            suffixIcon: _RevealButton(
              isObscured: _obscurePassword,
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordRequirementsList(password: _password.text),
          const SizedBox(height: AppSpacing.lg),

          AppTextField(
            controller: _confirmation,
            label: 'Confirm password',
            obscureText: _obscureConfirmation,
            textInputAction: TextInputAction.done,
            enabled: !isBusy,
            validator: (String? value) =>
                AuthValidators.passwordConfirmation(value, _password.text),
            onFieldSubmitted: (_) => _submit(),
            suffixIcon: _RevealButton(
              isObscured: _obscureConfirmation,
              onPressed: () =>
                  setState(() => _obscureConfirmation = !_obscureConfirmation),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),

          AppPrimaryButton(
            label: 'Create account',
            isBusy: isBusy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    // Clear a previous backend failure first, so a rejected attempt does not
    // leave a stale banner above a form the user has since corrected.
    ref.read(signUpControllerProvider.notifier).clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await ref
        .read(signUpControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  /// The backend's own words when they are fit to show, a generic line otherwise.
  ///
  /// Same rule as `AppErrorState`: only an [AppException] carries a message
  /// written to be read.
  static String _messageFor(Object error) => switch (error) {
    final AppException exception => exception.userMessage,
    _ => 'Something went wrong. Please try again.',
  };
}

/// Shown once the account exists.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.outcome});

  final SignUpOutcome outcome;

  @override
  Widget build(BuildContext context) {
    return switch (outcome) {
      SignUpNeedsConfirmation(email: final String email) => AppStateMessage(
        icon: Icons.mark_email_read_outlined,
        title: 'Check your email',
        message:
            'We sent a confirmation link to $email. Open it to finish setting '
            'up your account.',
      ),
      SignUpSignedIn() => const AppStateMessage(
        icon: Icons.check_circle_outline_rounded,
        title: 'Account created',
        message: 'You are signed in and ready to add your first bill.',
      ),
    };
  }
}

/// Show/hide toggle for a password field.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.isObscured, required this.onPressed});

  final bool isObscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      // A tooltip, because the icon alone is not a label a screen reader can
      // read out.
      tooltip: isObscured ? 'Show password' : 'Hide password',
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: context.colors.textTertiary,
      ),
    );
  }
}
