import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/validation/bill_validators.dart';
import '../controllers/add_bill_controller.dart';
import '../widgets/category_picker_field.dart';
import '../widgets/due_date_field.dart';

/// Records a bill.
///
/// ## Why it is a full screen and not a sheet
///
/// Six fields, one of which opens a date picker and another a category sheet. A
/// sheet that spawns a sheet is a stack the user cannot see the shape of, and on
/// a small phone the keyboard leaves a bottom sheet almost no room. Above the
/// shell, so the navigation bar does not sit under a form.
///
/// ## What is required and what is not
///
/// Name, amount and due date. Payee, category and notes are optional because
/// their columns are, and because the failure mode of a demanding form is not a
/// worse bill — it is no bill. Someone standing at a counter with a receipt
/// should be able to record it in three taps and tidy it up later.
///
/// ## Where "today" comes from
///
/// Read once per build from the device clock and passed down, so the date field's
/// bounds and the validator's bounds are the same value. Two calls to
/// `DateTime.now()` either side of midnight disagree, and the disagreement shows
/// up as a form that refuses a date its own picker offered.
class AddBillScreen extends ConsumerStatefulWidget {
  const AddBillScreen({super.key});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _payee = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// Set once the user has tried to submit.
  ///
  /// Until then the date field shows no error, because telling someone they have
  /// not filled in a field they have not reached yet is nagging rather than
  /// helping. `Form`'s own fields get this behaviour from `autovalidateMode`;
  /// the date picker is not one, so it needs the flag.
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _payee.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AddBillState state = ref.watch(addBillControllerProvider);
    final DateTime today = DateTime.now();

    ref.listen<AddBillState>(addBillControllerProvider, (
      AddBillState? previous,
      AddBillState next,
    ) {
      // Navigating during a build is an error, so leaving happens here.
      if (previous?.saved == null && next.saved != null) {
        _onSaved(next);
      }
    });

    final bool isBusy = state.isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add bill'),
        leading: IconButton(
          onPressed: isBusy ? null : () => _close(),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
        ),
      ),
      body: SafeArea(
        child: AppContentWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenInset,
                AppSpacing.lg,
                AppSpacing.screenInset,
                AppSpacing.xxxl,
              ),
              children: <Widget>[
                if (state.errorMessage case final String message) ...<Widget>[
                  AppInlineMessage(
                    message: message,
                    tone: AppStatusTone.overdue,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  borderRadius: AppRadii.panel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppTextField(
                        controller: _name,
                        label: 'Bill name',
                        hint: 'Meralco electricity',
                        textInputAction: TextInputAction.next,
                        enabled: !isBusy,
                        autofocus: true,
                        maxLength: BillValidators.maxNameLength,
                        validator: BillValidators.name,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppAmountField(
                        controller: _amount,
                        enabled: !isBusy,
                        // Rejects zero, unlike the column — see BillValidators.
                        validator: BillValidators.amount,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      DueDateField(
                        value: state.dueOn,
                        today: today,
                        enabled: !isBusy,
                        onChanged: ref
                            .read(addBillControllerProvider.notifier)
                            .setDueOn,
                        errorText: _submitted
                            ? BillValidators.dueDate(state.dueOn, today: today)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // The optional half, in its own card. Two surfaces rather than
                // one long form, so the three fields that matter are visibly the
                // three fields that matter.
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  borderRadius: AppRadii.panel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Details',
                        style: textTheme.titleSmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      CategoryPickerField(
                        selectedId: state.categoryId,
                        enabled: !isBusy,
                        onChanged: ref
                            .read(addBillControllerProvider.notifier)
                            .setCategory,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppTextField(
                        controller: _payee,
                        label: 'Paid to',
                        hint: 'Meralco',
                        helperText: 'Optional. Often the same as the name.',
                        textInputAction: TextInputAction.next,
                        enabled: !isBusy,
                        maxLength: BillValidators.maxPayeeLength,
                        validator: BillValidators.payee,
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      AppTextField(
                        controller: _notes,
                        label: 'Notes',
                        hint: 'Account number, reference, anything useful',
                        enabled: !isBusy,
                        maxLines: 3,
                        maxLength: BillValidators.maxNotesLength,
                        validator: BillValidators.notes,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),

                AppPrimaryButton(
                  label: 'Save bill',
                  isBusy: isBusy,
                  onPressed: () => _submit(today),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(DateTime today) async {
    // Set before validating, so the date field's error appears on the same tap
    // that reveals the text fields'.
    setState(() => _submitted = true);

    ref.read(addBillControllerProvider.notifier).clearError();

    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    final bool dateValid =
        BillValidators.dueDate(
          ref.read(addBillControllerProvider).dueOn,
          today: today,
        ) ==
        null;

    // Both checked before returning, rather than short-circuiting, so a form with
    // two problems shows both rather than one at a time.
    if (!fieldsValid || !dateValid) {
      return;
    }

    await ref
        .read(addBillControllerProvider.notifier)
        .submit(
          name: _name.text,
          amount: _amount.text,
          payee: _payee.text,
          notes: _notes.text,
        );
  }

  void _onSaved(AddBillState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${state.saved!.name} saved')));

    _close();
  }

  /// Leaves the form.
  ///
  /// `pop` when there is a stack, because this is pushed over whatever the user
  /// was looking at and they should return to it. The named fallback covers being
  /// opened directly, which a deep link or a test can do.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(AppRoutes.bills.routeName);
    }
  }
}
