import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/money.dart';
import '../../../../core/presentation/widgets/app_amount_field.dart';
import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../domain/entities/new_payment.dart';
import '../../domain/entities/payable_summary.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/validation/payment_validators.dart';
import '../controllers/payment_write_controller.dart';

/// Records a payment against one bill.
///
/// ## Why the amount is pre-filled and the sheet is still a form
///
/// The overwhelmingly common case is "I paid this bill" — the whole thing, today.
/// So the amount arrives filled with what is still owed and the date with today,
/// and that case is one tap on Save. Everything else on the sheet is optional and
/// can be ignored entirely.
///
/// A bare "Mark as paid" button would have served that case in *zero* taps, and
/// been wrong for every other one: a partial payment, a payment made last Tuesday,
/// a reference number worth keeping. Those are not edge cases in a bills app —
/// they are the reason the payments table has the columns it has. The form covers
/// all of them at the cost of one tap on the common path.
///
/// ## Overpaying warns and does not block
///
/// A surcharge, a rounded-up transfer, a bill two people in a household both
/// paid. The column permits it, so refusing here would leave someone unable to
/// record what their statement actually says. It is still nearly always a typo,
/// so it is said out loud beside the field.
///
/// Returns the amount recorded, or null if the sheet was dismissed without one.
Future<Money?> showRecordPaymentSheet({
  required BuildContext context,
  required PayableSummary payable,
}) => showAppBottomSheet<Money>(
  context: context,
  title: 'Record payment',
  child: _RecordPayment(payable: payable),
);

/// Opens the sheet and says what happened.
///
/// Every screen that can record a payment wants exactly this, so it lives once
/// rather than in each of them — the message in particular, which has to draw a
/// distinction the sheet itself does not: whether this settled the bill or only
/// paid part of it. Saying "marked as paid" about a partial payment would tell
/// the user they are done when they are not.
///
/// Returns true if something was recorded.
Future<bool> recordPaymentFor({
  required BuildContext context,
  required WidgetRef ref,
  required PayableSummary payable,
}) async {
  final Money? recorded = await showRecordPaymentSheet(
    context: context,
    payable: payable,
  );

  if (recorded == null || !context.mounted) {
    return recorded != null;
  }

  // Compared against what was owed when the sheet opened, which is the figure
  // the user was looking at. The re-read bill is authoritative and has not
  // necessarily arrived yet; waiting for it to phrase a sentence would delay the
  // confirmation behind a network call.
  final bool settled = recorded.minorUnits >= payable.outstanding.minorUnits;

  showAppToast(
    context,
    message: settled
        ? payable.settledMessage
        : payable.partialMessage(recorded),
    tone: AppToastTone.success,
  );

  return true;
}

class _RecordPayment extends ConsumerStatefulWidget {
  const _RecordPayment({required this.payable});

  final PayableSummary payable;

  @override
  ConsumerState<_RecordPayment> createState() => _RecordPaymentState();
}

class _RecordPaymentState extends ConsumerState<_RecordPayment> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final TextEditingController _reference = TextEditingController();
  final TextEditingController _note = TextEditingController();

  late DateTime _paidAt;
  PaymentMethod? _method;

  /// Extra fields, folded away until asked for.
  ///
  /// A reference number and a note are worth keeping and worth nobody having to
  /// scroll past. Behind a disclosure the sheet stays short enough that Save is
  /// visible without the keyboard covering it.
  bool _showDetails = false;

  /// Today, from the bill's own row rather than the device clock — the same date
  /// its status was computed against. See [BillWithStatus.today].
  DateTime get _today => widget.payable.today;

  @override
  void initState() {
    super.initState();

    // Pre-filled with the outstanding amount: the common case is paying the
    // whole thing. Formatted plainly, without grouping separators, because it
    // has to survive being read back by `Money.tryParse` when the user does not
    // touch it.
    _amount = TextEditingController(
      text: _plainAmount(widget.payable.outstanding),
    );
    _paidAt = _today;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final PaymentWriteState write = ref.watch(paymentWriteControllerProvider);

    final String? overpayment = PaymentValidators.overpaymentWarning(
      _amount.text,
      owed: widget.payable.outstanding,
    );

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _PayableLine(payable: widget.payable),
            const SizedBox(height: AppSpacing.xl),

            if (write.errorMessage case final String message) ...<Widget>[
              AppInlineMessage(
                message: message,
                tone: AppStatusTone.overdue,
                icon: Icons.error_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            AppAmountField(
              controller: _amount,
              label: 'Amount paid',
              enabled: !write.isSaving,
              validator: PaymentValidators.amount,
              // Rebuilds for the overpayment line and for the Save button's
              // enabled state, both of which follow the digits.
              onChanged: (_) => setState(() {}),
            ),
            if (overpayment case final String warning) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colors.dueSoonText,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      warning,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.dueSoonText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            _PaidOnField(
              value: _paidAt,
              today: _today,
              enabled: !write.isSaving,
              onChanged: (DateTime picked) => setState(() => _paidAt = picked),
            ),
            const SizedBox(height: AppSpacing.lg),

            _MethodPicker(
              value: _method,
              enabled: !write.isSaving,
              // Tapping the chosen method again clears it. The field is optional
              // and a picker with no way back to "unset" makes an accidental tap
              // permanent.
              onChanged: (PaymentMethod? picked) =>
                  setState(() => _method = picked),
            ),

            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: write.isSaving
                    ? null
                    : () => setState(() => _showDetails = !_showDetails),
                icon: Icon(
                  _showDetails
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                ),
                label: Text(_showDetails ? 'Fewer details' : 'Add a reference'),
              ),
            ),

            if (_showDetails) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _reference,
                label: 'Reference',
                hint: 'Receipt or confirmation number',
                enabled: !write.isSaving,
                maxLength: PaymentValidators.maxReferenceLength,
                validator: PaymentValidators.reference,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _note,
                label: 'Note',
                enabled: !write.isSaving,
                maxLines: 3,
                maxLength: PaymentValidators.maxNoteLength,
                validator: PaymentValidators.note,
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Record payment',
              isBusy: write.isSaving,
              onPressed: _canSave(write) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  bool _canSave(PaymentWriteState write) =>
      !write.isSaving &&
      PaymentValidators.isComplete(
        amount: _amount.text,
        paidAt: _paidAt,
        today: _today,
        reference: _reference.text,
        note: _note.text,
      );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final Money? amount = Money.tryParse(
      _amount.text,
      currency: widget.payable.outstanding.currency,
    );
    if (amount == null) {
      return;
    }

    final bool ok = await ref
        .read(paymentWriteControllerProvider.notifier)
        .record(
          NewPayment(
            target: widget.payable.target,
            amount: amount,
            // The date the user chose, at the moment they recorded it. A date
            // alone would put every payment at midnight and lose the order of
            // two made on the same day — which is exactly the pair someone is
            // trying to tell apart when they look at a history.
            paidAt: _withCurrentTime(_paidAt),
            method: _method,
            reference: _trimmedOrNull(_reference.text),
            note: _trimmedOrNull(_note.text),
          ),
        );

    if (!mounted || !ok) {
      return;
    }

    Navigator.of(context).pop(amount);
  }

  /// The chosen day, carrying the current time of day.
  ///
  /// For today that is simply now. For an earlier date it is that date at the
  /// present hour, which is a guess — but a guess that keeps the ordering within
  /// a day sane, and nothing in the app reads the hour of a back-dated payment.
  DateTime _withCurrentTime(DateTime day) {
    final DateTime now = DateTime.now();

    return DateTime(
      day.year,
      day.month,
      day.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  static String? _trimmedOrNull(String value) {
    final String trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  /// `1250.5` rather than `₱1,250.50`. What the amount field can read back.
  static String _plainAmount(Money value) =>
      (value.minorUnits / Money.minorPerMajor).toStringAsFixed(2);
}

/// What this is against, and what is left on it.
class _PayableLine extends StatelessWidget {
  const _PayableLine({required this.payable});

  final PayableSummary payable;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  payable.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  payable.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'STILL OWED',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                payable.outstanding.format(),
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// When the money moved.
///
/// A tappable field over the platform picker, like `DueDateField` — a typed date
/// needs a format to teach and an error for "13/13/2026"; a picker cannot produce
/// an invalid date at all.
///
/// **It will not offer tomorrow.** `lastDate` is today, so the one rule that
/// matters here is enforced by the control rather than reported by it.
class _PaidOnField extends StatelessWidget {
  const _PaidOnField({
    required this.value,
    required this.today,
    required this.enabled,
    required this.onChanged,
  });

  final DateTime value;
  final DateTime today;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Paid on',
          style: textTheme.labelLarge?.copyWith(
            color: enabled ? colors.textPrimary : colors.onDisabled,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Material(
          color: enabled ? colors.surfaceInput : colors.disabled,
          borderRadius: AppRadii.input,
          child: InkWell(
            onTap: enabled ? () => _pick(context) : null,
            borderRadius: AppRadii.input,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_available_outlined,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _label(),
                      style: textTheme.bodyLarge?.copyWith(
                        color: enabled ? colors.textPrimary : colors.onDisabled,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Today" rather than the date, when it is today. The word is what the reader
  /// is checking for, and it saves them comparing two dates to find out.
  String _label() {
    final DateTime day = DateTime(value.year, value.month, value.day);
    final DateTime anchor = DateTime(today.year, today.month, today.day);

    if (day == anchor) {
      return 'Today';
    }
    if (day == anchor.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    return DateFormat.yMMMEd().format(value);
  }

  Future<void> _pick(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(
        today.year - PaymentValidators.maxYearsInPast,
        today.month,
        today.day,
      ),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'When was it paid?',
    );

    if (picked != null) {
      onChanged(picked);
    }
  }
}

/// How it was paid. Optional, and cleared by tapping the chosen one again.
class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final PaymentMethod? value;
  final bool enabled;
  final ValueChanged<PaymentMethod?> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Method',
              style: textTheme.labelLarge?.copyWith(
                color: enabled ? colors.textPrimary : colors.onDisabled,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Optional',
              style: textTheme.bodySmall?.copyWith(color: colors.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Chips rather than a dropdown. Seven short labels fit in the space a
        // closed dropdown occupies plus one line, and picking GCash becomes one
        // tap instead of three.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final PaymentMethod method in PaymentMethod.values)
              _MethodChip(
                method: method,
                isSelected: method == value,
                enabled: enabled,
                onTap: () => onChanged(method == value ? null : method),
              ),
          ],
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.method,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      // `surface` with a border, not `surfaceMuted`: the muted tone is a hair
      // away from the canvas behind this sheet and an unselected chip drawn in it
      // is an invisible chip.
      color: isSelected ? colors.primarySoft : colors.surface,
      borderRadius: AppRadii.round,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadii.round,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.round,
            border: Border.all(
              color: isSelected ? colors.primary : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              method.label,
              style: textTheme.labelLarge?.copyWith(
                color: isSelected ? colors.primaryText : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
