import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validation/auth_validators.dart';

/// A live checklist of the password rules, under the password field.
///
/// Shown instead of a strength bar. A bar says "weak" without saying why; this
/// says exactly what is still missing, which is the only thing the user can act
/// on. Each rule is ticked as it is met, so the requirements are visible before
/// the field is submitted rather than arriving as an error afterwards.
class PasswordRequirementsList extends StatelessWidget {
  const PasswordRequirementsList({required this.password, super.key});

  /// The password as currently typed.
  final String password;

  @override
  Widget build(BuildContext context) {
    final PasswordRequirements met = AuthValidators.requirements(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Requirement(
          label: 'At least ${AuthValidators.minPasswordLength} characters',
          isMet: met.hasMinLength,
        ),
        _Requirement(label: 'A letter', isMet: met.hasLetter),
        _Requirement(label: 'A number', isMet: met.hasNumber),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({required this.label, required this.isMet});

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.colors;
    final Color colour = isMet ? palette.paidText : palette.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            isMet
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: colour,
          ),
          const SizedBox(width: AppSpacing.sm),
          // Flexible so a long rule wraps at a large font size.
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
