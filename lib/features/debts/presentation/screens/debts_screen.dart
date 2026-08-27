import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_card.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/debt_direction.dart';
import '../../domain/entities/debt_with_status.dart';
import '../controllers/debt_providers.dart';
import '../controllers/debt_write_controller.dart';
import '../widgets/debt_detail_sheet.dart';
import '../widgets/debt_tile.dart';

/// Utang, one side of the ledger at a time.
///
/// ## One screen, two directions
///
/// Money you owe and money owed to you are the same table with a `direction`
/// column, the same list, and the same actions. The only things that differ are
/// the words, so this takes the direction as a parameter rather than existing
/// twice — the argument the migration makes about the schema, applied to the
/// screen over it.
///
/// The switch at the top is how somebody gets from one to the other, and it is
/// on the screen rather than in the navigation bar because these two lists are
/// halves of one question.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({this.initialDirection = DebtDirection.iOwe, super.key});

  /// Which side to open on. The dashboard sends people to what they owe, which
  /// is the half with a deadline attached.
  final DebtDirection initialDirection;

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  late DebtDirection _direction = widget.initialDirection;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<DebtWithStatus>> debts = ref.watch(debtsProvider);

    // Failures from every write on this screen, in one place. The sheets and
    // dialogs that started them are gone by the time a request fails.
    ref.listen<DebtWriteState>(debtWriteControllerProvider, (
      DebtWriteState? previous,
      DebtWriteState next,
    ) {
      if (next.errorMessage case final String message
          when message != previous?.errorMessage) {
        showAppToast(context, message: message, tone: AppToastTone.error);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Utang'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.pushNamed(AppRoutes.addDebt.routeName),
            tooltip: 'Add utang',
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: AppContentWidth(
          child: switch (debts) {
            // Matched before the loading case. During a refresh the list is
            // already on screen and correct, and replacing it with a spinner
            // would blank it every time one is edited.
            AsyncValue<List<DebtWithStatus>>(
              value: final List<DebtWithStatus> found?,
            ) =>
              _Body(
                all: found,
                direction: _direction,
                onDirectionChanged: (DebtDirection value) =>
                    setState(() => _direction = value),
              ),
            AsyncError<List<DebtWithStatus>>(error: final Object error) =>
              AppErrorState(
                error: error,
                onRetry: () => ref.invalidate(debtsProvider),
              ),
            _ => const Center(child: AppLoadingIndicator()),
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.all,
    required this.direction,
    required this.onDirectionChanged,
  });

  final List<DebtWithStatus> all;
  final DebtDirection direction;
  final ValueChanged<DebtDirection> onDirectionChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DebtWithStatus> shown = all
        .where((DebtWithStatus each) => each.direction == direction)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        AppSpacing.bottomNavClearance,
      ),
      children: <Widget>[
        _DirectionSwitch(
          value: direction,
          // Counted across everything rather than the filtered list, so the
          // other tab's number is visible before switching to it. A tab that
          // does not say whether it has anything in it is a tab people stop
          // pressing.
          all: all,
          onChanged: onDirectionChanged,
        ),
        const SizedBox(height: AppSpacing.lg),

        if (shown.isEmpty)
          _Empty(direction: direction)
        else ...<Widget>[
          _Total(items: shown, direction: direction),
          const SizedBox(height: AppSpacing.lg),
          for (final DebtWithStatus item in shown) ...<Widget>[
            DebtTile(
              item: item,
              onTap: () =>
                  showDebtDetailSheet(context: context, ref: ref, item: item),
            ),
            const SizedBox(height: AppSpacing.cardGap),
          ],
        ],
      ],
    );
  }
}

/// What is still outstanding on this side of the ledger.
///
/// One figure, because a list of five debts is five subtractions somebody would
/// otherwise do in their head — and "how much am I in for" is the question this
/// screen exists to answer before any individual row matters.
class _Total extends StatelessWidget {
  const _Total({required this.items, required this.direction});

  final List<DebtWithStatus> items;
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final List<DebtWithStatus> open = items
        .where((DebtWithStatus each) => each.isOpen)
        .toList(growable: false);

    // Settled debts are excluded, the way a paused subscription is excluded from
    // the monthly figure: it is money that is no longer moving.
    final int total = open.fold<int>(
      0,
      (int sum, DebtWithStatus each) => sum + each.outstanding.minorUnits,
    );

    final String currency = items.first.outstanding.currency;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      borderRadius: AppRadii.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            direction.isOutgoing ? 'YOU STILL OWE' : 'STILL OWED TO YOU',
            style: textTheme.labelSmall?.copyWith(
              color: colors.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Money(minorUnits: total, currency: currency).format(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${open.length} open · ${items.length - open.length} settled',
            style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Which side of the ledger is showing.
class _DirectionSwitch extends StatelessWidget {
  const _DirectionSwitch({
    required this.value,
    required this.all,
    required this.onChanged,
  });

  final DebtDirection value;
  final List<DebtWithStatus> all;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (int index, DebtDirection option)
            in DebtDirection.values.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: AppSpacing.cardGap),
          Expanded(
            child: _DirectionButton(
              option: option,
              isSelected: option == value,
              count: all
                  .where(
                    (DebtWithStatus each) =>
                        each.direction == option && each.isOpen,
                  )
                  .length,
              onPressed: () => onChanged(option),
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.option,
    required this.isSelected,
    required this.count,
    required this.onPressed,
  });

  final DebtDirection option;
  final bool isSelected;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color foreground = isSelected
        ? colors.textOnPrimary
        : colors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? colors.primary : colors.surface,
        borderRadius: AppRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    option.isOutgoing ? 'I owe' : 'Owed to me',
                    maxLines: 1,
                    softWrap: false,
                    style: textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (count > 0) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$count',
                      style: textTheme.labelLarge?.copyWith(
                        color: isSelected ? foreground : colors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.direction});

  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: direction.isOutgoing
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      title: direction.isOutgoing ? 'You owe nobody' : 'Nobody owes you',
      message: direction.isOutgoing
          ? 'Record what you have borrowed and PayPaw will keep track of what '
                'is left as you pay it back.'
          : 'Record what you have lent and PayPaw will keep track of what is '
                'still to come back.',
      actionLabel: 'Add utang',
      onAction: () => context.pushNamed(AppRoutes.addDebt.routeName),
    );
  }
}
