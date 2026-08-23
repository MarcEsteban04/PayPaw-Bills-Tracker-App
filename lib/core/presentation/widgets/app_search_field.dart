import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import 'app_text_field.dart';

/// The search field from the reference design's search screen: a filled field
/// with a magnifier on the left and a filter control on the right.
///
/// It is a thin arrangement of [AppTextField] rather than its own input, so a
/// change to the shared field's fill or radius reaches search too.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.autofocus = false,
    super.key,
  });

  /// What is being searched — 'Search bills', not 'Search'.
  final String hint;

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Shows the trailing filter button when provided. Omit it and the button is
  /// not rendered, rather than rendered and inert.
  final VoidCallback? onFilterPressed;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      hint: hint,
      autofocus: autofocus,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: onFilterPressed == null
          ? null
          : IconButton(
              onPressed: onFilterPressed,
              icon: const Icon(Icons.tune_rounded),
              color: context.colors.textSecondary,
              tooltip: 'Filters',
            ),
    );
  }
}
