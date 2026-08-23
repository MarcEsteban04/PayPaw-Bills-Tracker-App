import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'app_text_field.dart';

/// Money input.
///
/// Exists as its own widget because getting currency entry right is fiddly and
/// worth doing once: a numeric-with-decimal keyboard, an input filter that
/// refuses anything but digits and a single decimal point, a peso prefix, and
/// tabular figures so the digits do not shift as they are typed.
///
/// It does not format as you type. Live grouping separators fight the caret, and
/// a bills app is better off formatting on display than while the user is
/// mid-number.
class AppAmountField extends StatelessWidget {
  const AppAmountField({
    this.controller,
    this.label = 'Amount',
    this.hint = '0.00',
    this.helperText,
    this.enabled = true,
    this.autofocus = false,
    this.validator,
    this.onChanged,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String hint;
  final String? helperText;
  final bool enabled;
  final bool autofocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  /// Digits, with at most one decimal point and at most two decimals.
  static final RegExp _allowed = RegExp(r'^\d*\.?\d{0,2}$');

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      helperText: helperText,
      enabled: enabled,
      autofocus: autofocus,
      validator: validator,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
        TextInputFormatter.withFunction(
          (TextEditingValue oldValue, TextEditingValue newValue) =>
              _allowed.hasMatch(newValue.text) ? newValue : oldValue,
        ),
      ],
      prefixIcon: const _PesoPrefix(),
    );
  }
}

/// The peso sign, sized and coloured to sit level with the entered digits.
///
/// A prefix icon rather than `prefixText` because `prefixText` only appears once
/// the field has focus, which makes an empty amount field look unlabelled.
class _PesoPrefix extends StatelessWidget {
  const _PesoPrefix();

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: Text(
          '₱',
          style: AppTypography.amount.copyWith(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
