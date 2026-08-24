import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/app_dropdown_field.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_filter_pill.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_meta_chip.dart';
import '../../../../core/presentation/widgets/app_search_field.dart';
import '../../../../core/presentation/widgets/app_skeleton.dart';
import '../../../../core/presentation/widgets/app_status_chip.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../recurring/domain/entities/recurrence.dart';
import '../../../recurring/presentation/widgets/recurrence_field.dart';

/// A gallery of every reusable component, live.
///
/// Developer tool, like the token gallery. Components here are interactive on
/// purpose: a button's busy state, a dialog's return value and a filter pill's
/// applied state are things that can only really be judged by tapping them.
class ComponentsScreen extends StatefulWidget {
  const ComponentsScreen({super.key});

  @override
  State<ComponentsScreen> createState() => _ComponentsScreenState();
}

class _ComponentsScreenState extends State<ComponentsScreen> {
  bool _isBusy = false;
  bool _isFilterApplied = false;
  _SampleCategory? _category;
  Recurrence? _recurrence;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Components')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenInset,
          0,
          AppSpacing.screenInset,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          _Section(
            title: 'Buttons',
            note: 'Tap "Save bill" to see the busy state block repeat taps.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppPrimaryButton(
                  label: 'Save bill',
                  icon: Icons.check_rounded,
                  isBusy: _isBusy,
                  onPressed: _simulateWork,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(label: 'Snooze reminder', onPressed: () {}),
                const SizedBox(height: AppSpacing.md),
                AppDangerButton(
                  label: 'Delete bill',
                  icon: Icons.delete_outline_rounded,
                  onPressed: _confirmDelete,
                ),
                const SizedBox(height: AppSpacing.md),
                const AppPrimaryButton(label: 'Disabled', onPressed: null),
              ],
            ),
          ),
          _Section(
            title: 'Cards',
            note: 'The second card is tappable — the ripple clips to its corners.',
            child: Column(
              children: <Widget>[
                const AppCard(child: Text('A plain card.')),
                const SizedBox(height: AppSpacing.cardGap),
                AppCard(
                  onTap: () => _showSnack('Card tapped'),
                  child: const Row(
                    children: <Widget>[
                      Expanded(child: Text('A tappable card.')),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _Section(
            title: 'Inputs',
            note:
                'Labels sit above the field, not floating inside it. The amount '
                'field refuses anything but digits and one decimal point.',
            child: Column(
              children: <Widget>[
                AppTextField(label: 'Bill name', hint: 'Meralco electricity'),
                SizedBox(height: AppSpacing.lg),
                AppAmountField(helperText: 'Amount due this cycle'),
                SizedBox(height: AppSpacing.lg),
                AppSearchField(hint: 'Search bills'),
              ],
            ),
          ),
          _Section(
            title: 'Dropdowns',
            child: AppDropdownField<_SampleCategory>(
              label: 'Category',
              hint: 'Choose a category',
              value: _category,
              items: _SampleCategory.values,
              itemLabel: (_SampleCategory value) => value.label,
              onChanged: (_SampleCategory? value) =>
                  setState(() => _category = value),
            ),
          ),
          _Section(
            title: 'Recurrence',
            note:
                'Tap it. The editor builds a rule from a unit and a count rather '
                'than a list of named presets, and previews the next three dates '
                'as they change — which is the only place "every month on the '
                '31st" admits what it does in February.',
            child: RecurrenceField(
              value: _recurrence,
              // A fixed date, not the device clock: a gallery that renders
              // differently every day is a gallery nobody can compare against
              // yesterday.
              today: DateTime(2026, 8, 25),
              onChanged: (Recurrence? value) =>
                  setState(() => _recurrence = value),
            ),
          ),
          _Section(
            title: 'Chips',
            note:
                'Grey chips carry facts. Coloured chips carry status, and always '
                'spell the status out so colour is never the only signal.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppMetaChip(label: 'Monthly'),
                    AppMetaChip(label: 'Electricity'),
                    AppMetaChip(label: 'GCash', icon: Icons.wallet_rounded),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppStatusChip(label: 'Paid', tone: AppStatusTone.paid),
                    AppStatusChip(
                      label: 'Due in 3 days',
                      tone: AppStatusTone.dueSoon,
                    ),
                    AppStatusChip(
                      label: 'Overdue',
                      tone: AppStatusTone.overdue,
                    ),
                    AppStatusChip(
                      label: 'Auto-pay',
                      tone: AppStatusTone.info,
                      icon: Icons.bolt_rounded,
                    ),
                    AppStatusChip(label: 'Draft', tone: AppStatusTone.neutral),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    AppFilterPill(
                      label: _isFilterApplied ? 'Electricity' : 'Category',
                      isApplied: _isFilterApplied,
                      onPressed: () =>
                          setState(() => _isFilterApplied = !_isFilterApplied),
                    ),
                    AppFilterPill(label: 'Status', onPressed: () {}),
                    AppFilterPill(label: 'Due date', onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
          _Section(
            title: 'Dialogs & sheets',
            note:
                'Dismissing a confirm dialog counts as "no", never as consent.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSecondaryButton(
                  label: 'Show a message',
                  onPressed: _showMessageDialog,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: 'Confirm something destructive',
                  onPressed: _confirmDelete,
                ),
                const SizedBox(height: AppSpacing.md),
                AppSecondaryButton(
                  label: 'Open a bottom sheet',
                  onPressed: _showSheet,
                ),
              ],
            ),
          ),
          const _Section(
            title: 'Empty state',
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 320,
                child: AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No bills yet',
                  message:
                      'Add your first bill and PayPaw will remind you before '
                      'it falls due.',
                  actionLabel: 'Add a bill',
                ),
              ),
            ),
          ),
          const _Section(
            title: 'Loading states',
            note:
                'A skeleton in the shape of the real row, so nothing jumps when '
                'the data lands. A spinner only says "wait".',
            child: Column(
              children: <Widget>[
                AppCard(child: _SkeletonRow()),
                SizedBox(height: AppSpacing.cardGap),
                AppCard(
                  child: SizedBox(height: 96, child: AppLoadingIndicator()),
                ),
              ],
            ),
          ),
          const _Section(
            title: 'Error state',
            note:
                'The message comes from the exception, not the screen. Anything '
                'that is not an AppException falls back to a generic line.',
            child: AppCard(
              padding: EdgeInsets.zero,
              child: SizedBox(
                height: 320,
                child: AppErrorState(error: NetworkException()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateWork() async {
    setState(() => _isBusy = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    setState(() => _isBusy = false);
    _showSnack('Saved');
  }

  Future<void> _showMessageDialog() async {
    await showAppDialog<void>(
      context: context,
      title: 'Reminder set',
      message:
          'PayPaw will notify you three days before this bill falls due, and '
          'again on the day.',
      actions: <Widget>[
        AppPrimaryButton(
          label: 'Got it',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _confirmDelete() async {
    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Delete this bill?',
      message: 'Its payment history goes with it. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (!mounted) {
      return;
    }
    _showSnack(confirmed ? 'Deleted' : 'Kept');
  }

  Future<void> _showSheet() async {
    await showAppBottomSheet<void>(
      context: context,
      title: 'Mark as paid',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppAmountField(label: 'Amount paid'),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'Confirm payment',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// A titled block with an optional note on what to look for.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: textTheme.titleMedium),
          if (note case final String text) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Skeletons arranged in the shape of a bill row: icon, name, meta, amount.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        AppSkeleton.circle(),
        const SizedBox(width: AppSpacing.md),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AppSkeleton(width: 140),
              SizedBox(height: AppSpacing.sm),
              AppSkeleton(width: 90, height: 12),
            ],
          ),
        ),
        const AppSkeleton(width: 64, height: 18),
      ],
    );
  }
}

/// Stand-in for the bill categories that Sprint 21 will model properly.
enum _SampleCategory {
  electricity('Electricity'),
  water('Water'),
  internet('Internet'),
  subscription('Subscription');

  const _SampleCategory(this.label);

  final String label;
}
