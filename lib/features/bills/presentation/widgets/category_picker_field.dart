import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';

/// Picks a category, or leaves it unset.
///
/// A bottom sheet rather than a dropdown. There are thirteen shared categories
/// before a user adds any of their own, each with an icon and a colour, and a
/// Material dropdown renders that as a cramped menu with no room for the icons
/// that make it scannable. The sheet is also where the reference design puts a
/// choice of this size.
///
/// Optional, and it says so. The column is nullable, and making someone
/// categorise a bill before they can record it is how a bill goes unrecorded.
class CategoryPickerField extends ConsumerWidget {
  const CategoryPickerField({
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String? selectedId;

  /// Null clears the selection.
  final ValueChanged<String?> onChanged;

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<List<Category>> categories = ref.watch(categoriesProvider);

    final Category? selected = switch (categories) {
      AsyncData<List<Category>>(value: final List<Category> list) =>
        list.where((Category c) => c.id == selectedId).firstOrNull,
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Category',
              style: textTheme.labelLarge?.copyWith(
                color: enabled ? colors.textPrimary : colors.onDisabled,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'optional',
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: enabled ? colors.surfaceInput : colors.disabled,
          borderRadius: AppRadii.input,
          child: InkWell(
            // Disabled while the list is still loading or has failed: a picker
            // that opens onto nothing is worse than one that waits.
            onTap: enabled && categories.hasValue
                ? () => _open(context, ref, categories.requireValue)
                : null,
            borderRadius: AppRadii.input,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  if (selected case final Category category) ...<Widget>[
                    CategoryIcon(category: category, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        category.name,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // Clearing is its own control. Re-opening the sheet to pick
                    // "none" would make removing a choice harder than making one.
                    IconButton(
                      onPressed: enabled ? () => onChanged(null) : null,
                      tooltip: 'Clear category',
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ] else ...<Widget>[
                    Icon(
                      Icons.category_outlined,
                      size: 20,
                      color: enabled ? colors.textSecondary : colors.onDisabled,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        switch (categories) {
                          AsyncError<List<Category>>() =>
                            'Categories unavailable',
                          AsyncLoading<List<Category>>() => 'Loading…',
                          _ => 'Choose a category',
                        },
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: enabled ? colors.textSecondary : colors.onDisabled,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) async {
    final String? picked = await showAppBottomSheet<String>(
      context: context,
      title: 'Category',
      child: _CategoryList(categories: categories, selectedId: selectedId),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.selectedId});

  final List<Category> categories;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return ListView.builder(
      shrinkWrap: true,
      itemCount: categories.length,
      itemBuilder: (BuildContext context, int index) {
        final Category category = categories[index];
        final bool isSelected = category.id == selectedId;

        return ListTile(
          onTap: () => Navigator.of(context).pop(category.id),
          leading: CategoryIcon(category: category),
          title: Text(category.name),
          trailing: isSelected
              ? Icon(Icons.check_circle_rounded, color: colors.primary)
              : null,
          selected: isSelected,
        );
      },
    );
  }
}
