import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_date_field.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/validation/bill_validators.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/new_debt.dart';

/// What the debt form holds, as one value.
///
/// The amount stays a **string** all the way to the caller, for the reason
/// `BillFormValues` gives: parsing it here and again in the validator would be
/// two definitions of what "1,250.50" means, and the one that disagrees is
/// always the one that runs.
@immutable
class DebtFormValues {
  const DebtFormValues({
    required this.direction,
    required this.counterpartyName,
    required this.amount,
    required this.incurredOn,
    this.counterpartyContact,
    this.dueOn,
    this.notes,
  });

  /// The values a form starts from when editing one that exists.
  factory DebtFormValues.of(Debt debt) => DebtFormValues(
    direction: debt.direction,
    counterpartyName: debt.counterpartyName,
    // Formatted the way the amount field formats, so opening a debt and saving
    // it untouched is not an edit.
    amount: debt.principal.formatBare(),
    incurredOn: debt.incurredOn,
    counterpartyContact: debt.counterpartyContact,
    dueOn: debt.dueOn,
    notes: debt.notes,
  );

  final DebtDirection direction;
  final String counterpartyName;
  final String amount;
  final DateTime incurredOn;
  final String? counterpartyContact;

  /// Null when nobody agreed a date, which is the common case for utang.
  final DateTime? dueOn;

  final String? notes;

  /// The parsed amount. Non-null by the time a caller sees this — the form
  /// validates the string before building one.
  Money get money => Money.tryParse(amount)!;

  /// The trimmed contact, or null. Empty is not the same as absent.
  String? get contact => _orNull(counterpartyContact);

  /// The trimmed notes, or null.
  String? get trimmedNotes => _orNull(notes);

  /// A draft ready for the repository.
  NewDebt toDraft() => NewDebt(
    direction: direction,
    counterpartyName: counterpartyName.trim(),
    counterpartyContact: contact,
    principal: money,
    incurredOn: incurredOn,
    dueOn: dueOn,
    notes: trimmedNotes,
  );

  static String? _orNull(String? value) {
    final String trimmed = value?.trim() ?? '';

    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The fields a debt has, and the button that saves them.
///
/// Shared by the add and edit screens, which differ in the button's word, what
/// happens on submit, and whether the fields start empty.
///
/// ## The direction is a choice, not a screen
///
/// Both sides of the ledger are one table with a `direction` column, and this is
/// one form with a two-way switch at the top. Two forms would be two copies of
/// six identical fields, and the day they drift is the day recording money you
/// lent works differently from recording money you borrowed.
class DebtForm extends ConsumerStatefulWidget {
  const DebtForm({
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.isSaving = false,
    this.errorMessage,
    super.key,
  });

  /// The word for what the button does.
  final String submitLabel;

  /// Called with the collected values once they validate.
  final void Function(DebtFormValues values) onSubmit;

  /// Null for a new debt.
  final DebtFormValues? initial;

  final bool isSaving;

  /// A failure from the write, shown above the fields.
  final String? errorMessage;

  @override
  ConsumerState<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends ConsumerState<DebtForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  late DebtDirection _direction;
  late DateTime _incurredOn;
  DateTime? _dueOn;

  /// Set once the user has tried to save, so the date pickers do not complain
  /// about fields nobody has reached yet.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    final DebtFormValues? initial = widget.initial;

    _name = TextEditingController(text: initial?.counterpartyName ?? '');
    _contact = TextEditingController(text: initial?.counterpartyContact ?? '');
    _amount = TextEditingController(text: initial?.amount ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _direction = initial?.direction ?? DebtDirection.iOwe;
    // Today, because the overwhelmingly common case is recording something that
    // just happened. A required date left blank would be a form that opens
    // already wrong.
    _incurredOn = initial?.incurredOn ?? _dateOnly(DateTime.now());
    _dueOn = initial?.dueOn;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isBusy = widget.isSaving;

    // Read once per build and passed down, so every field's bounds and every
    // validator's bounds are the same value.
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

            _DirectionPicker(
              value: _direction,
              enabled: !isBusy,
              onChanged: (DebtDirection value) =>
                  setState(() => _direction = value),
            ),
            const SizedBox(height: AppSpacing.lg),

            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderRadius: AppRadii.panel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppTextField(
                    controller: _name,
                    // The label follows the direction, because "who you owe" and
                    // "who owes you" are the two questions this field asks and
                    // a neutral "Person" would ask neither.
                    label: _direction.isOutgoing
                        ? 'Who you owe'
                        : 'Who owes you',
                    hint: 'Tita Ana',
                    textInputAction: TextInputAction.next,
                    enabled: !isBusy,
                    autofocus: widget.initial == null,
                    maxLength: NewDebt.maxNameLength,
                    validator: _validateName,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppAmountField(
                    controller: _amount,
                    // The default label already, but named because the field
                    // sits under two different questions depending on the
                    // direction and "Amount" is the word that works for both.
                    enabled: !isBusy,
                    validator: BillValidators.amount,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppDateField(
                    label: 'When it changed hands',
                    value: _incurredOn,
                    today: today,
                    firstDate: DateTime(
                      today.year - BillValidators.maxYearsInPast,
                    ),
                    lastDate: DateTime(today.year, today.month, today.day),
                    helpText: 'When did the money change hands?',
                    enabled: !isBusy,
                    onChanged: (DateTime date) =>
                        setState(() => _incurredOn = _dateOnly(date)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

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

                  AppDateField(
                    label: 'To be repaid by',
                    value: _dueOn,
                    today: today,
                    firstDate: _incurredOn,
                    lastDate: DateTime(
                      today.year + BillValidators.maxYearsInFuture,
                      12,
                      31,
                    ),
                    helpText: 'When is it meant to be repaid?',
                    // Says what leaving it empty *means*, rather than looking
                    // like a field somebody forgot. Plenty of utang has no date,
                    // and inventing one would be inventing a promise.
                    placeholder: 'No date agreed',
                    enabled: !isBusy,
                    onCleared: () => setState(() => _dueOn = null),
                    onChanged: (DateTime date) =>
                        setState(() => _dueOn = _dateOnly(date)),
                    errorText: _submitted ? _dueDateProblem() : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _contact,
                    label: 'How to reach them',
                    hint: '0917 555 1234',
                    helperText: 'Optional. A number, an email, anything.',
                    textInputAction: TextInputAction.next,
                    enabled: !isBusy,
                    maxLength: NewDebt.maxContactLength,
                    validator: _validateContact,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _notes,
                    label: 'Notes',
                    hint: 'What it was for, what was agreed',
                    enabled: !isBusy,
                    maxLines: 3,
                    maxLength: NewDebt.maxNotesLength,
                    validator: BillValidators.notes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),

            AppPrimaryButton(
              label: widget.submitLabel,
              isBusy: isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  String? _validateName(String? value) {
    final String trimmed = value?.trim() ?? '';

    if (trimmed.isEmpty) {
      return _direction.isOutgoing ? 'Say who you owe' : 'Say who owes you';
    }
    if (trimmed.length > NewDebt.maxNameLength) {
      return 'Keep this under ${NewDebt.maxNameLength} characters';
    }

    return null;
  }

  String? _validateContact(String? value) {
    if ((value?.trim().length ?? 0) > NewDebt.maxContactLength) {
      return 'Keep this under ${NewDebt.maxContactLength} characters';
    }

    return null;
  }

  /// The one rule the picker cannot enforce on its own.
  ///
  /// `firstDate` already stops a date before the money changed hands being
  /// *picked* — but the incurred date can be moved afterwards, leaving a repay
  /// date behind it.
  String? _dueDateProblem() {
    if (_dueOn case final DateTime due when due.isBefore(_incurredOn)) {
      return 'This is before the money changed hands';
    }

    return null;
  }

  void _submit() {
    setState(() => _submitted = true);

    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    final bool dateValid = _dueDateProblem() == null;

    // Both evaluated before returning, rather than short-circuiting, so a form
    // with two problems shows both rather than one at a time.
    if (!fieldsValid || !dateValid) {
      return;
    }

    widget.onSubmit(
      DebtFormValues(
        direction: _direction,
        counterpartyName: _name.text,
        amount: _amount.text,
        incurredOn: _incurredOn,
        counterpartyContact: _contact.text,
        dueOn: _dueOn,
        notes: _notes.text,
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

/// Which way the money went.
///
/// Two large targets rather than a dropdown or a switch. It is the single most
/// consequential field on the form — get it wrong and the app tells somebody
/// they owe money they are owed — so it is the one thing that should be
/// impossible to set by accident and obvious to read back.
class _DirectionPicker extends StatelessWidget {
  const _DirectionPicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final DebtDirection value;
  final ValueChanged<DebtDirection> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (int index, DebtDirection option)
            in DebtDirection.values.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: _DirectionOption(
              option: option,
              isSelected: option == value,
              enabled: enabled,
              onPressed: () => onChanged(option),
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
    required this.option,
    required this.isSelected,
    required this.enabled,
    required this.onPressed,
  });

  final DebtDirection option;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color background = isSelected ? colors.primary : colors.surface;
    final Color foreground = isSelected
        ? colors.textOnPrimary
        : colors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: background,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  option.isOutgoing
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 20,
                  color: isSelected ? foreground : colors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    option.isOutgoing ? 'I owe' : 'Owed to me',
                    maxLines: 1,
                    softWrap: false,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
