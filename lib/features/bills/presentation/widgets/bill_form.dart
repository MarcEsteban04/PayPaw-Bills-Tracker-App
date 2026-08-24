import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../recurring/domain/entities/recurrence.dart';
import '../../../recurring/presentation/widgets/recurrence_field.dart';
import '../../domain/entities/bill.dart';
import '../../domain/validation/bill_validators.dart';
import 'category_picker_field.dart';
import 'due_date_field.dart';

/// What the form holds, as one value.
///
/// The amount stays a **string** all the way to the caller. Parsing it here and
/// again in the validator would be two definitions of what "1,250.50" means, and
/// the one that disagrees is always the one that runs.
@immutable
class BillFormValues {
  const BillFormValues({
    required this.name,
    required this.amount,
    required this.dueOn,
    this.categoryId,
    this.payee,
    this.notes,
    this.recurrence,
  });

  /// The values a form starts from when editing an existing bill.
  factory BillFormValues.of(Bill bill) => BillFormValues(
    name: bill.name,
    // Formatted the way the amount field formats, so opening a bill and saving
    // it without touching anything is not an edit. `formatBare` groups with
    // commas and `Money.tryParse` strips them, so it round-trips exactly.
    amount: bill.amount.formatBare(),
    dueOn: bill.dueOn,
    categoryId: bill.categoryId,
    payee: bill.payee,
    notes: bill.notes,
  );

  final String name;
  final String amount;
  final DateTime? dueOn;
  final String? categoryId;
  final String? payee;
  final String? notes;

  /// The schedule, when this is a repeating obligation rather than one bill.
  ///
  /// **Setting it changes what saving does.** A bill with a recurrence is stored
  /// as a template in `recurring_bills`, and the occurrences are generated from
  /// it — including the first one. Saving does not create a bill directly, which
  /// is why the form says so before it is submitted.
  final Recurrence? recurrence;

  /// The parsed amount, or null when the string is not one.
  Money? get money => Money.tryParse(amount);
}

/// The six fields a bill has, and the button that saves them.
///
/// Shared by the add and edit screens. They differ in three things — the label on
/// the button, what happens on submit, and whether the fields start empty — and
/// nothing else. Two copies of six fields with two pickers between them would
/// drift within a sprint: the first version of this file was the add screen only,
/// and edit would have been a copy of it.
///
/// ## What owns what
///
/// This widget owns the field state: four `TextEditingController`s, the picked
/// date and the picked category. That is deliberate — text belongs in a
/// `TextEditingController`, and mirroring it into a notifier means two copies of
/// the same string to keep in step. The *controller* above owns only what
/// survives the form: whether a write is in flight, and what it said if it
/// failed.
class BillForm extends ConsumerStatefulWidget {
  const BillForm({
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.isSaving = false,
    this.errorMessage,
    this.showRecurrence = true,
    super.key,
  });

  /// 'Save bill' or 'Save changes'. The word for what the button does, not a
  /// generic 'Submit' that tells the user nothing about which screen they are on.
  final String submitLabel;

  /// Called with the collected values once they validate.
  final void Function(BillFormValues values) onSubmit;

  /// Null for a new bill.
  final BillFormValues? initial;

  final bool isSaving;

  /// A failure from the write, shown above the fields.
  final String? errorMessage;

  /// Whether to offer the Repeat field.
  ///
  /// **Off when editing.** `BillWriteController.update` writes a `Bill`, and a
  /// recurrence is not one of its columns — so the field took a value and threw
  /// it away on save, which is worse than not offering it at all. Turning an
  /// existing bill into a schedule, or changing the schedule behind one, is
  /// Sprint 32.
  final bool showRecurrence;

  @override
  ConsumerState<BillForm> createState() => _BillFormState();
}

class _BillFormState extends ConsumerState<BillForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _payee;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  DateTime? _dueOn;
  String? _categoryId;
  Recurrence? _recurrence;

  /// Set once the user has tried to save.
  ///
  /// Until then the date field shows no error, because telling someone off for a
  /// field they have not reached is nagging rather than helping. `Form`'s own
  /// fields get this from `autovalidateMode`; the date picker is not one of them,
  /// so it needs the flag.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    final BillFormValues? initial = widget.initial;

    _name = TextEditingController(text: initial?.name ?? '');
    _payee = TextEditingController(text: initial?.payee ?? '');
    _amount = TextEditingController(text: initial?.amount ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _dueOn = initial?.dueOn;
    _categoryId = initial?.categoryId;
    _recurrence = initial?.recurrence;
  }

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
    final bool isBusy = widget.isSaving;

    // Read once per build and passed down, so the date field's bounds and the
    // validator's bounds are the same value. Two `DateTime.now()` calls either
    // side of midnight disagree, and the disagreement shows up as a form refusing
    // a date its own picker offered.
    final DateTime today = DateTime.now();

    return AppContentWidth(
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
            if (widget.errorMessage case final String message) ...<Widget>[
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
                    // Only on a new bill. Opening an existing one and having the
                    // keyboard cover it is not what someone came to do.
                    autofocus: widget.initial == null,
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
                    value: _dueOn,
                    today: today,
                    enabled: !isBusy,
                    onChanged: (DateTime date) => setState(
                      // Normalised to midnight. A bill is due on a day, and a
                      // time smuggled in from a picker formats differently
                      // depending on where the device is.
                      () => _dueOn = DateTime(date.year, date.month, date.day),
                    ),
                    errorText: _submitted
                        ? BillValidators.dueDate(_dueOn, today: today)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // The optional half, on its own card. Two surfaces rather than one
            // long form, so the three fields that matter are visibly the three
            // fields that matter.
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
                    selectedId: _categoryId,
                    enabled: !isBusy,
                    onChanged: (String? id) => setState(() => _categoryId = id),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  if (widget.showRecurrence) ...<Widget>[
                    RecurrenceField(
                      value: _recurrence,
                      today: today,
                      // The due date, so a rule opens on the day already typed
                      // above rather than on today.
                      startFrom: _dueOn,
                      enabled: !isBusy,
                      onChanged: (Recurrence? value) =>
                          setState(() => _recurrence = value),
                    ),
                    // Saving a repeating bill creates a schedule, not the bill in
                    // front of you — the occurrences come from the generator. Said
                    // here rather than discovered afterwards, when the list shows a
                    // bill dated differently from the due date that was typed.
                    if (_recurrence != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Saved as a repeating bill. PayPaw will add each one as it '
                        'comes due.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],

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
              label: widget.submitLabel,
              isBusy: isBusy,
              onPressed: () => _submit(today),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(DateTime today) {
    // Set before validating, so the date field's error appears on the same tap
    // that reveals the text fields'.
    setState(() => _submitted = true);

    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    final bool dateValid = BillValidators.dueDate(_dueOn, today: today) == null;

    // Both evaluated before returning, rather than short-circuiting, so a form
    // with two problems shows both rather than one at a time.
    if (!fieldsValid || !dateValid) {
      return;
    }

    widget.onSubmit(
      BillFormValues(
        name: _name.text,
        amount: _amount.text,
        dueOn: _dueOn,
        categoryId: _categoryId,
        payee: _payee.text,
        notes: _notes.text,
        recurrence: _recurrence,
      ),
    );
  }
}
