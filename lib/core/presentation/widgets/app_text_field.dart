import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_spacing.dart';

/// PayPaw's text input.
///
/// The fill, radius, border and focus colour all come from the theme's
/// `InputDecorationTheme`. What this widget adds is the **label above the
/// field** rather than Material's floating label.
///
/// That is a deliberate departure: the reference design has no form fields to
/// copy, and a static label is easier to scan down a column of inputs than one
/// that animates and shrinks. It also leaves the field's interior free for a
/// hint, which a floating label competes with.
///
/// Wrap in a `Form` and pass [validator] for validation.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController? controller;

  /// Shown above the field. Omit for a field whose purpose is obvious from
  /// context, such as a search box.
  final String? label;

  /// Placeholder inside the field. Should be an example, not a repeat of the
  /// label.
  final String? hint;

  /// Guidance below the field. Replaced by the validation error when there is
  /// one.
  final String? helperText;

  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    final Widget field = TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        // The label lives above the field, so Material's own label is off.
        counterText: maxLength == null ? null : '',
      ),
    );

    if (label case final String labelText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              labelText,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          field,
        ],
      );
    }

    return field;
  }
}
