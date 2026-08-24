import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_dropdown_field.dart';
import '../../../../core/presentation/widgets/app_inline_message.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/recurrence.dart';
import '../../domain/entities/recurrence_frequency.dart';

/// What the editor was closed with.
///
/// Three outcomes, not two. "Dismissed" and "cleared" are different answers —
/// swiping the sheet away must leave an existing rule alone, and tapping
/// **Does not repeat** must remove it — so a bare `Recurrence?` cannot express
/// both.
sealed class RecurrenceEditorResult {
  const RecurrenceEditorResult();
}

/// The user chose a schedule.
class RecurrenceChosen extends RecurrenceEditorResult {
  const RecurrenceChosen(this.recurrence);

  final Recurrence recurrence;
}

/// The user chose not to repeat at all.
class RecurrenceCleared extends RecurrenceEditorResult {
  const RecurrenceCleared();
}

/// Builds or edits a [Recurrence].
///
/// Returns null when dismissed. See [RecurrenceEditorResult] for why clearing is
/// not the same thing.
Future<RecurrenceEditorResult?> showRecurrenceEditor({
  required BuildContext context,
  required DateTime today,
  Recurrence? initial,
  DateTime? startFrom,
}) => showAppBottomSheet<RecurrenceEditorResult>(
  context: context,
  title: 'Repeat',
  child: _RecurrenceEditor(
    initial: initial,
    today: today,
    startFrom: startFrom,
  ),
);

/// The editor.
///
/// ## Interval and frequency are separate controls
///
/// Rather than one list of "Weekly / Bi-weekly / Monthly / Every 3 months / …".
/// Those are the same two facts — a unit and a count — and a flat list has to
/// enumerate their product, which is where "custom" comes from as a concept.
/// A unit chip plus a stepper covers every combination the model allows,
/// including the ones nobody thought to put on a list.
///
/// ## The preview is the point
///
/// A rule is a set of claims about dates, and "every month on the 31st" does not
/// tell anyone what February does. Showing the next three dates as they are built
/// turns the whole control into something checkable, and it is the only place the
/// month-end clamping is visible before a bill is generated months later.
class _RecurrenceEditor extends StatefulWidget {
  const _RecurrenceEditor({
    required this.initial,
    required this.today,
    required this.startFrom,
  });

  final Recurrence? initial;
  final DateTime today;

  /// Where a *new* rule should begin, when the screen already knows.
  ///
  /// The bill form passes the due date the user has already picked, because the
  /// two are the same fact: someone who typed "due 20 September" and then asked
  /// for it monthly means the 20th. Defaulting to today instead made the editor
  /// open on a different day from the one on the form behind it and quietly
  /// disagree with it.
  ///
  /// Only a default. An existing rule keeps its own start, and changing the due
  /// date afterwards does not silently rewrite a schedule the user configured.
  final DateTime? startFrom;

  @override
  State<_RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<_RecurrenceEditor> {
  late RecurrenceFrequency _frequency;
  late int _interval;
  late int _dayOfMonth;
  late int _weekday;
  late int _monthOfYear;
  late DateTime _startsOn;
  late DateTime? _endsOn;

  @override
  void initState() {
    super.initState();

    final Recurrence? initial = widget.initial;
    _frequency = initial?.frequency ?? RecurrenceFrequency.monthly;
    _interval = initial?.intervalCount ?? 1;
    _startsOn = initial?.startsOn ?? widget.startFrom ?? widget.today;
    _endsOn = initial?.endsOn;

    // Defaults taken from the start date rather than fixed, so a new rule already
    // describes the day the user is on instead of an arbitrary one they have to
    // notice and correct.
    _dayOfMonth = initial?.dayOfMonth ?? _startsOn.day;
    _weekday = initial?.weekday ?? _startsOn.weekday;
    _monthOfYear = initial?.monthOfYear ?? _startsOn.month;
  }

  /// The rule as currently configured. Rebuilt on every change rather than
  /// mutated, so the preview and the validation always describe what would be
  /// saved.
  Recurrence get _recurrence => Recurrence(
    frequency: _frequency,
    intervalCount: _interval,
    dayOfMonth: _frequency.needsWeekday ? null : _dayOfMonth,
    weekday: _frequency.needsWeekday ? _weekday : null,
    monthOfYear: _frequency.needsMonthOfYear ? _monthOfYear : null,
    startsOn: _startsOn,
    endsOn: _endsOn,
  );

  @override
  Widget build(BuildContext context) {
    final Recurrence rule = _recurrence;
    final String? problem = rule.validate();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Label('How often'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final RecurrenceFrequency value
                  in RecurrenceFrequency.values)
                _Chip(
                  label: _frequencyLabel(value),
                  isSelected: value == _frequency,
                  onPressed: () => setState(() => _frequency = value),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          _Label('Repeat every'),
          const SizedBox(height: AppSpacing.sm),
          _IntervalStepper(
            value: _interval,
            unit: _unitLabel(rule),
            onChanged: (int value) => setState(() => _interval = value),
          ),

          const SizedBox(height: AppSpacing.xl),
          ..._detailControls(),

          const SizedBox(height: AppSpacing.xl),
          _Label('Starts'),
          const SizedBox(height: AppSpacing.sm),
          _DateRow(value: _startsOn, onPressed: () => _pickStart()),

          const SizedBox(height: AppSpacing.lg),
          _Label('Ends'),
          const SizedBox(height: AppSpacing.sm),
          _DateRow(
            value: _endsOn,
            emptyLabel: 'Never',
            onPressed: _pickEnd,
            onClear: _endsOn == null
                ? null
                : () => setState(() => _endsOn = null),
          ),

          const SizedBox(height: AppSpacing.xl),
          if (problem case final String message)
            AppInlineMessage(
              message: message,
              tone: AppStatusTone.overdue,
              icon: Icons.error_outline_rounded,
            )
          else
            _Preview(recurrence: rule, today: widget.today),

          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: AppSecondaryButton(
                  label: 'Does not repeat',
                  onPressed: () =>
                      Navigator.of(context).pop(const RecurrenceCleared()),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppPrimaryButton(
                  label: 'Save',
                  // Null rather than a button that reports the problem on tap:
                  // the message is already on screen above it.
                  onPressed: problem != null
                      ? null
                      : () => Navigator.of(context).pop(RecurrenceChosen(rule)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The controls a frequency actually needs, and only those.
  ///
  /// A weekly rule showing a day-of-month picker would be offering a field that
  /// changes nothing — and the shape constraint in the database says the same
  /// thing about which fields each frequency uses.
  List<Widget> _detailControls() {
    if (_frequency.needsWeekday) {
      return <Widget>[
        _Label('On'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (int day = DateTime.monday; day <= DateTime.sunday; day++)
              _Chip(
                label: _weekdayShortName(day),
                isSelected: day == _weekday,
                onPressed: () => setState(() => _weekday = day),
              ),
          ],
        ),
      ];
    }

    return <Widget>[
      if (_frequency.needsMonthOfYear) ...<Widget>[
        AppDropdownField<int>(
          label: 'Month',
          value: _monthOfYear,
          items: List<int>.generate(12, (int i) => i + 1),
          itemLabel: (int month) =>
              DateFormat.MMMM().format(DateTime(2026, month)),
          onChanged: (int? value) =>
              setState(() => _monthOfYear = value ?? _monthOfYear),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
      AppDropdownField<int>(
        label: 'Day of the month',
        value: _dayOfMonth,
        // The sentinel first, because "the last day" is the answer for anything
        // billed at month end and picking 31 for it is the mistake this exists to
        // prevent.
        items: <int>[
          Recurrence.lastDayOfMonth,
          ...List<int>.generate(31, (int i) => i + 1),
        ],
        itemLabel: (int day) =>
            day == Recurrence.lastDayOfMonth ? 'Last day' : '$day',
        onChanged: (int? value) =>
            setState(() => _dayOfMonth = value ?? _dayOfMonth),
      ),
    ];
  }

  Future<void> _pickStart() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime(widget.today.year - 5),
      lastDate: DateTime(widget.today.year + 10, 12, 31),
      helpText: 'Repeats from',
    );

    if (picked != null) {
      setState(() {
        _startsOn = picked;
        // An end date now in the past would make the rule produce nothing, and
        // the user did not ask to end it — they moved the start.
        if (_endsOn case final DateTime end when end.isBefore(picked)) {
          _endsOn = null;
        }
      });
    }
  }

  Future<void> _pickEnd() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endsOn ?? _startsOn,
      // Never before the start: an end date that precedes it is a rule that can
      // produce nothing, and refusing to offer it beats validating it afterwards.
      firstDate: _startsOn,
      lastDate: DateTime(widget.today.year + 20, 12, 31),
      helpText: 'Repeats until',
    );

    if (picked != null) {
      setState(() => _endsOn = picked);
    }
  }

  static String _frequencyLabel(RecurrenceFrequency frequency) =>
      switch (frequency) {
        RecurrenceFrequency.weekly => 'Weekly',
        RecurrenceFrequency.monthly => 'Monthly',
        RecurrenceFrequency.quarterly => 'Quarterly',
        RecurrenceFrequency.yearly => 'Yearly',
      };

  /// 'week' / 'weeks', matching the stepper's count.
  String _unitLabel(Recurrence rule) {
    final String unit = switch (rule.frequency) {
      RecurrenceFrequency.weekly => 'week',
      RecurrenceFrequency.monthly => 'month',
      RecurrenceFrequency.quarterly => 'quarter',
      RecurrenceFrequency.yearly => 'year',
    };

    return _interval == 1 ? unit : '${unit}s';
  }

  static String _weekdayShortName(int weekday) {
    // 4 January 2026 is a Sunday, so +1 is Monday and +7 is Sunday — the ISO
    // numbering DateTime.weekday uses.
    return DateFormat.E().format(DateTime(2026, 1, 4 + weekday));
  }
}

/// The next few dates this rule produces.
///
/// Three, because one does not show a pattern and a longer list stops being
/// glanceable. This is where "every month on the 31st" admits what it does in
/// February.
class _Preview extends StatelessWidget {
  const _Preview({required this.recurrence, required this.today});

  final Recurrence recurrence;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<DateTime> next = recurrence.occurrencesFrom(today);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              recurrence.describe(),
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              next.isEmpty
                  // Reachable with an end date before the first occurrence. Said
                  // plainly rather than shown as an empty list, which reads as a
                  // control that has not finished loading.
                  ? 'This never comes due.'
                  : 'Next: ${next.map(DateFormat.MMMd().format).join(' · ')}',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A count with a minus and a plus, bounded by what the column allows.
///
/// Not a text field. The value is 1 to 60, almost always under 6, and a keyboard
/// for that is a keyboard covering the sheet the user is trying to read.
class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  static const int _min = 1;
  static const int _max = 60;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Row(
      children: <Widget>[
        _StepButton(
          icon: Icons.remove_rounded,
          semanticLabel: 'Less often',
          onPressed: value > _min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          semanticLabel: 'More often',
          onPressed: value < _max ? () => onChanged(value + 1) : null,
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          unit,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: colors.surfaceMuted,
        // Kept when disabled, which `styleFrom` otherwise drops to transparent.
        // At the bottom of the range the minus button lost its circle entirely
        // while the plus kept one, and a control changing shape reads as a
        // rendering fault rather than as unavailable.
        disabledBackgroundColor: colors.disabled,
        foregroundColor: colors.textPrimary,
        disabledForegroundColor: colors.onDisabled,
        // 48dp, the minimum tap target, rather than the 40dp default.
        minimumSize: const Size.square(48),
      ),
    );
  }
}

/// A date, or the word standing in for not having one.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.value,
    required this.onPressed,
    this.emptyLabel = 'Pick a date',
    this.onClear,
  });

  final DateTime? value;
  final VoidCallback onPressed;
  final String emptyLabel;

  /// Shown only when there is something to clear.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final String label = value == null
        ? emptyLabel
        : DateFormat.yMMMd().format(value!);

    return Row(
      children: <Widget>[
        Expanded(
          child: Material(
            color: colors.surfaceMuted,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
            child: InkWell(
              onTap: onPressed,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md + 2,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? colors.textTertiary
                            : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onClear case final VoidCallback clear) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: clear,
            tooltip: 'Clear the end date',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ],
    );
  }
}

/// A small-caps section label, matching the bills screen's headings.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.colors.textTertiary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

/// A selectable option. Not `AppFilterPill`, which means "this narrows a list".
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? colors.primary : colors.surfaceMuted,
        borderRadius: AppRadii.chip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.chip,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              // 44dp tall at the default text size. Below 48, but these sit in a
              // wrap with 8dp between rows, so the gaps are not dead space.
              vertical: AppSpacing.md,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? colors.textOnPrimary : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
