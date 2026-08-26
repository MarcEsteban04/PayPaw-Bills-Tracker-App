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
import '../../../bills/presentation/widgets/category_picker_field.dart';
import '../../../recurring/domain/entities/recurrence.dart';
import '../../../recurring/presentation/widgets/recurrence_field.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/validation/subscription_validators.dart';

/// What the subscription form holds, as one value.
///
/// The amount stays a **string** all the way to the caller, for the reason
/// `BillFormValues` gives: parsing it here and again in the validator would be
/// two definitions of what "1,250.50" means, and the one that disagrees is
/// always the one that runs.
@immutable
class SubscriptionFormValues {
  const SubscriptionFormValues({
    required this.provider,
    required this.amount,
    required this.recurrence,
    this.name,
    this.planName,
    this.categoryId,
    this.trialEndsOn,
    this.autoRenews = true,
    this.cancellationUrl,
  });

  /// The values a form starts from when editing one that exists.
  factory SubscriptionFormValues.of(Subscription subscription) =>
      SubscriptionFormValues(
        provider: subscription.details.provider,
        // Formatted the way the amount field formats, so opening a subscription
        // and saving it untouched is not an edit.
        amount: subscription.amount.formatBare(),
        recurrence: subscription.recurrence,
        // Blank when it matches the provider, because that is what the form
        // means by "leave it empty" — showing the provider back in an optional
        // field makes it look deliberately overridden.
        name: subscription.name.trim() == subscription.details.provider.trim()
            ? null
            : subscription.name,
        planName: subscription.details.planName,
        categoryId: subscription.template.categoryId,
        trialEndsOn: subscription.details.trialEndsOn,
        autoRenews: subscription.details.autoRenews,
        cancellationUrl: subscription.details.cancellationUrl,
      );

  final String provider;
  final String amount;

  /// The billing cycle.
  ///
  /// **Never null here**, unlike a bill's. A subscription that does not repeat
  /// is a purchase, and the form refuses to submit without one rather than
  /// storing a template that charges once and stops.
  final Recurrence recurrence;

  /// What to call it in PayPaw, when the provider's own name is not enough.
  /// Null falls back to the provider.
  final String? name;

  final String? planName;
  final String? categoryId;
  final DateTime? trialEndsOn;
  final bool autoRenews;
  final String? cancellationUrl;

  /// The parsed amount. Non-null by the time a caller sees this — the form
  /// validates the string before building one.
  Money get money => Money.tryParse(amount)!;

  /// The plan to store.
  ///
  /// Empty is not the same as absent: a blank plan means "no plan", which is a
  /// null column, not an empty string that formats later as a stray separator
  /// after the provider's name.
  String? get plan {
    final String trimmed = planName?.trim() ?? '';

    return trimmed.isEmpty ? null : trimmed;
  }

  /// The label to store: the typed one, or the provider.
  String get effectiveName {
    if (name case final String value when value.trim().isNotEmpty) {
      return value.trim();
    }

    return provider.trim();
  }
}

/// The fields a subscription has, and the button that saves them.
///
/// Shared by the add and edit screens, which differ in the button's word, what
/// happens on submit, and whether the fields start empty. `BillForm` earned this
/// shape the hard way and this follows it deliberately.
///
/// ## Why the provider leads and the name is optional
///
/// A subscription is identified by **who charges for it**. "Family plan" tells
/// nobody what it is a plan for, and asking for a name first would make people
/// type "Netflix" into a field labelled something else. The provider becomes the
/// name unless the user says otherwise, which covers the two-Netflix-accounts
/// case without charging everybody else a field for it.
///
/// ## What owns what
///
/// This widget owns the field state — five `TextEditingController`s, the picked
/// dates, the category, the rule and the renew switch. The controller above owns
/// only what survives the form: whether a write is in flight and what it said if
/// it failed.
class SubscriptionForm extends ConsumerStatefulWidget {
  const SubscriptionForm({
    required this.submitLabel,
    required this.onSubmit,
    this.initial,
    this.isSaving = false,
    this.errorMessage,
    super.key,
  });

  /// 'Save subscription' or 'Save changes'. The word for what the button does.
  final String submitLabel;

  /// Called with the collected values once they validate.
  final void Function(SubscriptionFormValues values) onSubmit;

  /// Null for a new subscription.
  final SubscriptionFormValues? initial;

  final bool isSaving;

  /// A failure from the write, shown above the fields.
  final String? errorMessage;

  @override
  ConsumerState<SubscriptionForm> createState() => _SubscriptionFormState();
}

class _SubscriptionFormState extends ConsumerState<SubscriptionForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _provider;
  late final TextEditingController _plan;
  late final TextEditingController _amount;
  late final TextEditingController _name;
  late final TextEditingController _cancellationUrl;

  Recurrence? _recurrence;
  DateTime? _trialEndsOn;
  String? _categoryId;
  bool _autoRenews = true;

  /// Set once the user has tried to save.
  ///
  /// Until then the pickers show no error, because telling someone off for a
  /// field they have not reached is nagging rather than helping. `Form`'s own
  /// fields get this from `autovalidateMode`; these two are not `Form` fields.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();

    final SubscriptionFormValues? initial = widget.initial;

    _provider = TextEditingController(text: initial?.provider ?? '');
    _plan = TextEditingController(text: initial?.planName ?? '');
    _amount = TextEditingController(text: initial?.amount ?? '');
    _name = TextEditingController(text: initial?.name ?? '');
    _cancellationUrl = TextEditingController(
      text: initial?.cancellationUrl ?? '',
    );
    _recurrence = initial?.recurrence;
    _trialEndsOn = initial?.trialEndsOn;
    _categoryId = initial?.categoryId;
    _autoRenews = initial?.autoRenews ?? true;
  }

  @override
  void dispose() {
    _provider.dispose();
    _plan.dispose();
    _amount.dispose();
    _name.dispose();
    _cancellationUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool isBusy = widget.isSaving;

    // Read once per build and passed down, so every field's bounds and every
    // validator's bounds are the same value. Two `DateTime.now()` calls either
    // side of midnight disagree, and the disagreement shows up as a form
    // refusing a date its own picker offered.
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
                    controller: _provider,
                    label: 'Service',
                    hint: 'Netflix',
                    helperText: 'Who charges you for it.',
                    textInputAction: TextInputAction.next,
                    enabled: !isBusy,
                    // Only on a new subscription. Opening an existing one and
                    // having the keyboard cover it is not what someone came to
                    // do.
                    autofocus: widget.initial == null,
                    maxLength: SubscriptionValidators.maxNameLength,
                    validator: SubscriptionValidators.provider,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppAmountField(
                    controller: _amount,
                    label: 'Amount per charge',
                    enabled: !isBusy,
                    validator: BillValidators.amount,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  RecurrenceField(
                    value: _recurrence,
                    today: today,
                    // Not "Repeat / Does not repeat". A subscription that does
                    // not repeat is a purchase, and this form refuses to save
                    // one — so resting on the single answer it will not accept
                    // would be the field lying about the form it is in.
                    label: 'Billing cycle',
                    emptyLabel: 'Choose how often',
                    enabled: !isBusy,
                    onChanged: (Recurrence? value) =>
                        setState(() => _recurrence = value),
                  ),
                  if (_submitted && _recurrence == null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: Text(
                        'Choose how often it charges',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.overdueText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    // The "Starts" date inside the rule editor is not an
                    // abstract schedule anchor here — it is the day money next
                    // leaves. Said before it is set, rather than discovered
                    // afterwards when a bill appears on a date nobody expected.
                    'The date the cycle starts on is when it next charges. '
                    'PayPaw adds a bill each time it comes due.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textTertiary,
                    ),
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

                  AppTextField(
                    controller: _plan,
                    label: 'Plan',
                    hint: 'Premium',
                    helperText:
                        'Optional. Which plan, where there are several.',
                    textInputAction: TextInputAction.next,
                    enabled: !isBusy,
                    maxLength: SubscriptionValidators.maxNameLength,
                    validator: SubscriptionValidators.planName,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  CategoryPickerField(
                    selectedId: _categoryId,
                    enabled: !isBusy,
                    onChanged: (String? id) => setState(() => _categoryId = id),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppDateField(
                    label: 'Free trial ends',
                    value: _trialEndsOn,
                    today: today,
                    firstDate: DateTime(
                      today.year - BillValidators.maxYearsInPast,
                    ),
                    lastDate: DateTime(
                      today.year + SubscriptionValidators.maxTrialYears,
                      12,
                      31,
                    ),
                    helpText: 'When does the free period end?',
                    placeholder: 'No free trial',
                    enabled: !isBusy,
                    onCleared: () => setState(() => _trialEndsOn = null),
                    onChanged: (DateTime date) => setState(
                      // Normalised to midnight. A trial ends on a day, and a
                      // time smuggled in from a picker formats differently
                      // depending on where the device is.
                      () => _trialEndsOn = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      ),
                    ),
                    errorText: _submitted
                        ? SubscriptionValidators.trialEndsOn(
                            _trialEndsOn,
                            today: today,
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _autoRenews,
                    onChanged: isBusy
                        ? null
                        : (bool value) => setState(() => _autoRenews = value),
                    title: Text(
                      'Renews automatically',
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      // What turning it off is *for*. It is not a way to stop
                      // the subscription — that is the pause in the drawer — it
                      // records that the user has already cancelled and is
                      // running out the clock.
                      'Turn this off once you have cancelled with the provider '
                      'and are using out the time you paid for.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _cancellationUrl,
                    label: 'Where to cancel',
                    hint: 'netflix.com/cancelplan',
                    helperText:
                        'Optional. Finding this page again is the hard part.',
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    enabled: !isBusy,
                    maxLength: SubscriptionValidators.maxUrlLength,
                    validator: SubscriptionValidators.cancellationUrl,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    controller: _name,
                    label: 'Call it something else',
                    hint: 'Netflix — mum',
                    helperText: 'Optional. Defaults to the service name.',
                    enabled: !isBusy,
                    maxLength: SubscriptionValidators.maxNameLength,
                    validator: SubscriptionValidators.name,
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
    // Set before validating, so the pickers' errors appear on the same tap that
    // reveals the text fields'.
    setState(() => _submitted = true);

    final bool fieldsValid = _formKey.currentState?.validate() ?? false;
    final Recurrence? rule = _recurrence;
    final bool trialValid =
        SubscriptionValidators.trialEndsOn(_trialEndsOn, today: today) == null;

    // All three evaluated before returning, rather than short-circuiting, so a
    // form with three problems shows all three rather than one at a time.
    if (!fieldsValid || rule == null || !trialValid) {
      return;
    }

    widget.onSubmit(
      SubscriptionFormValues(
        provider: _provider.text.trim(),
        amount: _amount.text,
        recurrence: rule,
        name: _name.text,
        planName: _plan.text,
        categoryId: _categoryId,
        trialEndsOn: _trialEndsOn,
        autoRenews: _autoRenews,
        // Normalised here rather than at the repository, so what is stored is
        // what the validator accepted and not a second interpretation of it.
        cancellationUrl: SubscriptionValidators.normalizeUrl(
          _cancellationUrl.text,
        ),
      ),
    );
  }
}
