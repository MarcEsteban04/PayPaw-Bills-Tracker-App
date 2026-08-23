import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

/// A select, styled like [AppTextField] so a form of mixed inputs reads as one
/// set of controls.
///
/// Generic over the value so callers keep their own type — a category enum, a
/// biller entity — instead of passing strings around and parsing them back.
/// [itemLabel] is what turns that value into something displayable.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
    this.label,
    this.hint,
    this.enabled = true,
    this.validator,
    super.key,
  });

  /// Selectable values, in display order.
  final List<T> items;

  /// How to render one value.
  final String Function(T value) itemLabel;

  /// Null disables the field, matching Material's convention.
  final ValueChanged<T?>? onChanged;

  /// Currently selected value, or null for nothing selected.
  final T? value;

  /// Shown above the field.
  final String? label;

  /// Shown inside the field while nothing is selected.
  final String? hint;

  final bool enabled;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget field = DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: true,
      hint: hint == null ? null : Text(hint!, style: textTheme.bodyMedium),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      iconEnabledColor: context.colors.textSecondary,
      // The menu is a surface of its own, so it gets the card radius rather
      // than the field's.
      borderRadius: AppRadii.card,
      dropdownColor: context.colors.surface,
      style: textTheme.bodyLarge,
      items: <DropdownMenuItem<T>>[
        for (final T item in items)
          DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))),
      ],
    );

    if (label case final String labelText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(labelText, style: textTheme.titleSmall),
          ),
          field,
        ],
      );
    }

    return field;
  }
}
