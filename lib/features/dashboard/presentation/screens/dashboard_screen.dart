import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/presentation/layout/app_content_width.dart';
import '../../../../core/presentation/widgets/app_empty_state.dart';
import '../../../../core/presentation/widgets/app_error_state.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/controllers/current_user_provider.dart';
import '../../../bills/domain/entities/bill_outlook.dart';
import '../../../bills/domain/entities/bill_status.dart';
import '../../../bills/domain/entities/bill_totals.dart';
import '../../../bills/domain/entities/bill_with_status.dart';
import '../../../bills/domain/entities/upcoming_schedule.dart';
import '../../../bills/presentation/controllers/bill_detail_provider.dart';
import '../../../bills/presentation/widgets/bill_detail_sheet.dart';
import '../../../bills/presentation/widgets/bill_list_tile.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/presentation/controllers/category_providers.dart';
import '../../../categories/presentation/widgets/category_icon.dart';
import '../../../notifications/domain/entities/notification_permission.dart';
import '../../../notifications/presentation/controllers/notification_providers.dart';
import '../../../notifications/presentation/widgets/reminder_permission_card.dart';
import '../../../payments/presentation/widgets/pay_bill_picker_sheet.dart';
import '../../../payments/presentation/widgets/record_payment_sheet.dart';
import '../../../profile/presentation/controllers/profile_providers.dart';
import '../../../recurring/domain/entities/recurring_bill.dart';
import '../../../recurring/domain/entities/recurring_commitment.dart';
import '../../../recurring/presentation/controllers/recurring_bill_providers.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_quick_actions.dart';
import '../widgets/dashboard_skeleton.dart';

/// PayPaw's landing screen.
///
/// ## The shape, and where it comes from
///
/// The reference design's dashboard reads top to bottom as: who you are, one big
/// figure, the two things you can do about it, a strip of shortcuts, then the
/// detail. This follows that order, because it is the order the questions arrive
/// in — "how much do I owe" before "what is it made of".
///
/// ## What it is not
///
/// **Not the bills list with a different header.** Bills already answers "show me
/// everything, let me search it". This answers "what needs me today", so it lists
/// overdue and the next two weeks in full and counts the rest, with a way through
/// to the list. Two tabs that show the same rows are one tab and a wasted tap.
///
/// It also does not repeat the summary card. That card is the Bills screen's hero
/// and reusing it here would make the two screens open identically.
///
/// Sprints 35 to 38 deepen each block — the financial summary, the upcoming
/// grouping, the remaining quick actions, and the polish. This is the structure
/// they hang on.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BillWithStatus>> bills = ref.watch(billsProvider);

    return Scaffold(
      body: SafeArea(
        child: AppContentWidth(
          child: RefreshIndicator(
            // The only way to ask for fresh figures was to kill the app. The
            // dashboard is the screen a user opens to check on something, which
            // makes "is this current?" the question it has to be able to answer.
            onRefresh: () => ref.refresh(billsProvider.future),
            child: _Scaffold(
              ref: ref,
              // Which *state* the screen is in, not which data it holds. The
              // crossfade should play once when the placeholders give way to the
              // real thing, and never when a figure changes — a whole screen
              // that fades on every refresh is a screen that flickers.
              stateKey: switch (bills) {
                AsyncValue<List<BillWithStatus>>(hasValue: true) => 'data',
                AsyncError<List<BillWithStatus>>() => 'error',
                _ => 'loading',
              },
              children: _body(context, ref, bills),
            ),
          ),
        ),
      ),
    );
  }

  /// The blocks for whichever state the bills are in.
  ///
  /// ## Data outranks loading, whenever there is any
  ///
  /// This used to match on `AsyncLoading` first, which is right exactly once —
  /// the first fetch. Every refresh after that is *also* `AsyncLoading`, with the
  /// previous value still attached, so recording a payment blanked the entire
  /// screen back to placeholders and rebuilt it. The user's own action looked
  /// like the app losing its place.
  ///
  /// So the order is: show what we have; fall back to the error only when there
  /// is nothing to show instead.
  ///
  /// **A failed refresh keeps the old figures rather than replacing them with a
  /// red panel.** They are still true as of the last fetch, and a dashboard that
  /// throws away good data because a background poll failed is worse than one
  /// that is briefly a minute out of date. The pull gesture is how the user asks
  /// again.
  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<BillWithStatus>> bills,
  ) => switch (bills) {
    AsyncValue<List<BillWithStatus>>(value: final List<BillWithStatus> list?) =>
      _blocks(context, ref, list),
    AsyncError<List<BillWithStatus>>(error: final Object error) => <Widget>[
      AppErrorState(error: error, onRetry: () => ref.invalidate(billsProvider)),
    ],
    _ => DashboardSkeleton.blocks(),
  };

  /// Everything under the header, once the bills have arrived.
  List<Widget> _blocks(
    BuildContext context,
    WidgetRef ref,
    List<BillWithStatus> bills,
  ) {
    final BillTotals totals = BillTotals.of(bills);
    final List<BillWithStatus> overdue = _overdue(bills);

    // `today` from a bill row rather than the device clock — the same date the
    // statuses on this screen were computed against. Falls back only when there
    // are no bills, and then nothing below depends on it.
    final DateTime today = bills.firstOrNull?.today ?? DateTime.now();
    final BillOutlook outlook = BillOutlook.of(bills, today: today);
    final UpcomingSchedule schedule = UpcomingSchedule.of(bills, today: today);

    return <Widget>[
      _Hero(totals: totals),
      const SizedBox(height: AppSpacing.sectionGap),

      DashboardQuickActions(
        actions: _actions(context, ref, bills),
        destinations: _destinations(context),
      ),

      if (outlook.hasAnything) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _StatRow(totals: totals, outlook: outlook, today: today),
      ],

      // Only for someone who has bills to be reminded about, and only while
      // there is something the tap could change.
      //
      // The condition is read here rather than left to the card, because the
      // *gap* has to go with it: a card that shrinks to nothing still leaves the
      // spacing before it, and a dashboard with a stray section gap in it looks
      // like something failed to load.
      if (bills.isNotEmpty && _needsPermission(ref)) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        const ReminderPermissionCard(),
      ],

      if (overdue.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        // Above upcoming, always. Something already late outranks something that
        // has not happened yet, and a dashboard that buries it under "what is
        // next" is answering the wrong question first.
        _Section(
          label: 'Needs paying now',
          count: overdue.length,
          bills: overdue,
          onOpen: (BillWithStatus item) => _openDetail(context, ref, item),
        ),
      ],

      const SizedBox(height: AppSpacing.sectionGap),
      if (bills.isEmpty)
        AppEmptyState(
          icon: Icons.receipt_long_rounded,
          title: 'No bills yet',
          message:
              'Add the first one and PayPaw will keep track of it for you.',
          actionLabel: 'Add bill',
          onAction: () => context.pushNamed(AppRoutes.addBill.routeName),
        )
      else if (schedule.isEmpty)
        // Bills exist, but none of them are waiting on anything. Said plainly
        // rather than shown as an empty heading, and it is genuinely good news.
        _AllClear(hasOverdue: overdue.isNotEmpty)
      else ...<Widget>[
        // Grouped by how soon rather than listed flat. "Due in 6 days" is a
        // subtraction the reader has to do before they know whether it matters;
        // "Next week" is the answer.
        // Gaps lead rather than trail, so the last block here does not stack its
        // own spacing on top of whatever follows.
        for (final (int index, UpcomingGroup group)
            in schedule.listed.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpacing.sectionGap),
          _Section(
            label: group.window.label,
            count: group.bills.length,
            bills: group.bills,
            onOpen: (BillWithStatus item) => _openDetail(context, ref, item),
          ),
        ],
        // Everything past next week, counted rather than listed. This screen
        // answers "what needs me now", and a bill six weeks out does not — but
        // pretending it is not there would be worse.
        if (schedule.tail case final UpcomingGroup tail) ...<Widget>[
          if (schedule.listed.isNotEmpty)
            const SizedBox(height: AppSpacing.sectionGap),
          _LaterSummary(
            group: tail,
            onSeeAll: () => context.goNamed(AppRoutes.bills.routeName),
          ),
        ],
      ],

      // The charts sit last on purpose. Everything above is actionable — a bill
      // to open, a button to press; these are context, and context that pushes
      // the actionable part below the fold has the screen the wrong way round.
      if (outlook.byCategory.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _CategoryBreakdown(outlook: outlook),
      ],
      if (outlook.hasAnything) ...<Widget>[
        const SizedBox(height: AppSpacing.sectionGap),
        _MonthsAhead(outlook: outlook),
      ],
    ];
  }

  /// The things that change something. See [DashboardQuickActions] on the split.
  List<QuickAction> _actions(
    BuildContext context,
    WidgetRef ref,
    List<BillWithStatus> bills,
  ) {
    final List<BillWithStatus> payable = payableBills(bills);

    return <QuickAction>[
      QuickAction(
        icon: Icons.add_rounded,
        label: 'Add bill',
        onPressed: () => context.pushNamed(AppRoutes.addBill.routeName),
      ),
      // Absent when there is nothing to pay, rather than present and opening onto
      // an empty sheet. Same rule the whole row follows: only actions that work.
      if (payable.isNotEmpty)
        QuickAction(
          icon: Icons.check_circle_outline_rounded,
          label: 'Mark paid',
          onPressed: () => unawaited(_markPaid(context, ref, payable)),
        ),
    ];
  }

  /// The things that only go somewhere.
  ///
  /// Two of the three are also tabs. That is not duplication for its own sake:
  /// somebody reading the dashboard's figures is already thinking about bills,
  /// and making them re-aim at the navigation bar to act on that thought is a
  /// tax. What it does mean is that they are not *important*, which is why they
  /// are drawn quietly — see [DashboardQuickActions].
  ///
  /// Subscriptions is the one with no tab and no other route in.
  List<QuickAction> _destinations(BuildContext context) {
    return <QuickAction>[
      QuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'All bills',
        onPressed: () => context.goNamed(AppRoutes.bills.routeName),
      ),
      QuickAction(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        onPressed: () => context.goNamed(AppRoutes.calendar.routeName),
      ),
      QuickAction(
        icon: Icons.subscriptions_outlined,
        label: 'Subscriptions',
        onPressed: () => context.pushNamed(AppRoutes.subscriptions.routeName),
      ),
    ];
  }

  /// Asks which bill, then records against it.
  ///
  /// Two sheets in sequence rather than one combined picker-and-form: the picker
  /// has to close before the form opens, or the form's amount field ends up
  /// under a list the user has already finished with.
  static Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    List<BillWithStatus> payable,
  ) async {
    final BillWithStatus? chosen = await showPayBillPicker(
      context: context,
      bills: payable,
    );

    if (chosen == null || !context.mounted) {
      return;
    }

    await recordPaymentFor(context: context, ref: ref, item: chosen);
  }

  /// Whether reminders are blocked and something can still be done about it.
  ///
  /// False while the platform is being asked, which is a moment: a card that
  /// appears a beat after the screen settles, offering something the user did
  /// not ask for, reads as an advert rather than as part of the screen.
  static bool _needsPermission(WidgetRef ref) {
    final NotificationPermission? permission = ref
        .watch(notificationPermissionProvider)
        .value;

    return permission != null && !permission.allowsPosting;
  }

  /// Everything late, soonest first — which for overdue means longest overdue.
  static List<BillWithStatus> _overdue(List<BillWithStatus> bills) =>
      bills.where((BillWithStatus b) => b.status == BillStatus.overdue).toList()
        ..sort(
          (BillWithStatus a, BillWithStatus b) =>
              a.bill.dueOn.compareTo(b.bill.dueOn),
        );

  static Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    BillWithStatus item,
  ) async {
    final BillDetailAction? action = await showBillDetailSheet(
      context: context,
      item: item,
    );

    if (!context.mounted || action == null) {
      return;
    }

    // Recording a payment is handled here, and so is Edit. Archive and delete are
    // not: a dashboard that can delete a bill is a dashboard that needs every
    // confirmation and undo the list already has, duplicated.
    //
    // Paying is the exception because it is the thing this screen exists to
    // prompt. It also needs no confirmation and no undo — a payment recorded by
    // mistake is corrected by removing it, not by a countdown in a toast.
    if (action == BillDetailAction.recordPayment) {
      await recordPaymentFor(context: context, ref: ref, item: item);
      return;
    }

    if (action == BillDetailAction.edit) {
      // Not awaited: the caller does not care when the editor closes, and the
      // list it returns to is invalidated by the save itself.
      unawaited(
        context.pushNamed(
          AppRoutes.editBill.routeName,
          pathParameters: <String, String>{'id': item.bill.id},
        ),
      );
    }
  }
}

/// The header, then whatever the screen currently has to say.
class _Scaffold extends StatelessWidget {
  const _Scaffold({
    required this.ref,
    required this.children,
    required this.stateKey,
  });

  final WidgetRef ref;
  final List<Widget> children;

  /// Identifies the *state* — loading, error, data — so the body crossfades once
  /// on the way in and holds still afterwards. Keyed on the data instead, every
  /// refresh would fade the screen out and back.
  final String stateKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Always scrollable, even when the content is short. The pull-to-refresh
      // gesture needs somewhere to travel, and a dashboard with two bills on it
      // does not overflow the screen — which is exactly when someone wonders
      // whether the figures are current.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenInset,
        AppSpacing.lg,
        AppSpacing.screenInset,
        // Clears the floating navigation bar and the add button beside it.
        AppSpacing.bottomNavClearance + AppSpacing.xl,
      ),
      children: <Widget>[
        DashboardHeader(
          email: ref.watch(currentUserProvider).value?.email,
          name: ref.watch(displayNameProvider),
          now: DateTime.now(),
          onAvatarPressed: () => context.goNamed(AppRoutes.settings.routeName),
        ),
        const SizedBox(height: AppSpacing.sectionGap),
        // One switcher over the whole body rather than a stagger down the list.
        //
        // A staggered entrance would look considered and read as slow: every
        // block after the first is deliberately withheld from someone who opened
        // this screen to find out one number. A single short crossfade covers the
        // swap from placeholders and gets out of the way.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(
            key: ValueKey<String>(stateKey),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// The figure the screen exists to show, and what it is made of.
///
/// Light, unlike the Bills screen's dark card. The two screens open on the same
/// number and would otherwise be indistinguishable at a glance — and this one is
/// followed by shortcuts, which need the green to themselves.
class _Hero extends StatelessWidget {
  const _Hero({required this.totals});

  final BillTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            // Centre is the default and is what this needs: the ring is taller
            // than the label and figure beside it, and top-aligning left a band
            // of empty card under the text that read as something missing.
            children: <Widget>[
              Expanded(child: _Figures(totals: totals)),
              // Only once there is a denominator. A ring at 0% of nothing is a
              // grey circle that invites the reader to work out what it means.
              if (totals.hasProgress) ...<Widget>[
                const SizedBox(width: AppSpacing.lg),
                ProgressRing(
                  fraction: totals.settledFraction,
                  caption: 'settled',
                ),
              ],
            ],
          ),
          if (totals.hasProgress) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              '${totals.settled.format()} of ${totals.billed.format()} paid off',
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The label, the number, and the chips — the left half of the hero card.
class _Figures extends StatelessWidget {
  const _Figures({required this.totals});

  final BillTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'TOTAL OUTSTANDING',
          style: textTheme.labelSmall?.copyWith(
            color: colors.textTertiary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Scaled down rather than wrapped or clipped. The ring takes 96 of the
        // card's ~320, so a seven-figure total at display size does not fit —
        // and a headline that wraps mid-number is unreadable.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          // Counts to its new value when it moves, and only then. On this screen
          // the figure moves because the user recorded a payment or added a
          // bill, so the count is the app showing the effect of what they just
          // did rather than silently redrawing.
          child: AnimatedMoney(
            value: totals.outstanding,
            style: textTheme.displaySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
      ],
    );
  }
}

/// Two figures that answer "when", which the headline cannot.
///
/// ₱5,500 outstanding is a different month depending on whether it all lands in
/// three weeks or spreads over six.
class _StatRow extends ConsumerWidget {
  const _StatRow({
    required this.totals,
    required this.outlook,
    required this.today,
  });

  final BillTotals totals;
  final BillOutlook outlook;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;

    // Null while the templates are still arriving, which is a moment. The other
    // three figures do not wait for it — a summary that blanks because one of
    // four numbers is late is a summary that is usually blank.
    final RecurringCommitment? commitment = switch (ref.watch(
      recurringBillsProvider,
    )) {
      AsyncData<List<RecurringBill>>(value: final List<RecurringBill> all) =>
        RecurringCommitment.of(all),
      _ => null,
    };

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DashboardCardTitle(title: 'The money'),
          const SizedBox(height: AppSpacing.lg),
          _FigureRow(
            left: SummaryFigure(
              label: 'Upcoming',
              value: totals.upcoming.format(),
              caption: '${outlook.dueThisMonth.format()} this month',
              tint: colors.dueSoon,
            ),
            right: SummaryFigure(
              label: 'Overdue',
              value: totals.overdue.format(),
              caption: totals.overdueCount == 1
                  ? '1 bill late'
                  : '${totals.overdueCount} bills late',
              tint: colors.overdue,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _FigureRow(
            left: SummaryFigure(
              label: 'Paid',
              value: totals.settled.format(),
              caption: totals.hasProgress
                  ? '${(totals.settledFraction * 100).round()}% of everything'
                  : null,
              tint: colors.primary,
            ),
            right: SummaryFigure(
              label: 'Every month',
              // A dash rather than a zero while it loads. "₱0.00" is a claim,
              // and it is the wrong one for anyone who does have schedules.
              value: commitment?.perMonth.format() ?? '—',
              // The count, not the yearly figure. "₱192,000.00 a year, on
              // average" was truncated to "on ave…" in half the card's width,
              // and a caption that has to be guessed at is worse than a shorter
              // one — the number of schedules is also the more useful fact,
              // since it is what the reader would go and check.
              caption: switch (commitment) {
                null => 'counting…',
                final RecurringCommitment c when !c.hasAnything =>
                  'nothing repeats',
                final RecurringCommitment c when c.activeCount == 1 =>
                  'from 1 schedule',
                final RecurringCommitment c =>
                  'from ${c.activeCount} schedules',
              },
              tint: colors.info,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two figures sharing a row, each with half the width.
///
/// A plain `Row` of `Expanded`s rather than a `GridView`: two of them is not a
/// grid, and a scrollable inside a scrollable is a wrestling match.
class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: right),
      ],
    );
  }
}

/// Where the outstanding money is going.
class _CategoryBreakdown extends ConsumerWidget {
  const _CategoryBreakdown({required this.outlook});

  final BillOutlook outlook;

  /// The palette a slice falls back to when its category has no colour, and what
  /// "Other" and "Uncategorised" always use.
  ///
  /// Taken from the categories themselves wherever possible: a breakdown whose
  /// colours do not match the icons on the rows above it is a second colour
  /// language for the same things.
  static const List<int> _fallback = <int>[
    0xFF6366F1,
    0xFF0EA5E9,
    0xFFF59E0B,
    0xFFEC4899,
    0xFF14B8A6,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette colors = context.colors;
    final List<Category> categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];

    Category? lookup(String? id) =>
        categories.where((Category c) => c.id == id).firstOrNull;

    String nameOf(CategorySlice slice) {
      if (slice.isOther) {
        return 'Everything else';
      }

      return lookup(slice.categoryId)?.name ?? 'Uncategorised';
    }

    Color colorOf(CategorySlice slice, int index) {
      if (!slice.isOther) {
        final Color? own = CategoryIcons.parseColor(
          lookup(slice.categoryId)?.colorHex,
        );
        if (own != null) {
          return own;
        }
      }

      return Color(_fallback[index % _fallback.length]);
    }

    final List<CategorySlice> slices = outlook.byCategory;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const DashboardCardTitle(
            title: 'Where it goes',
            subtitle: 'Outstanding by category',
          ),
          const SizedBox(height: AppSpacing.lg),
          StackedBar(
            slices: <BandSlice>[
              for (int i = 0; i < slices.length; i++)
                BandSlice(
                  share: slices[i].share,
                  color: colorOf(slices[i], i),
                  label: nameOf(slices[i]),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BreakdownLegend(
            rows: <LegendRow>[
              for (int i = 0; i < slices.length; i++)
                LegendRow(
                  color: colorOf(slices[i], i),
                  label: nameOf(slices[i]),
                  // Rounded, and never to zero: a slice that exists is at least
                  // "1%", because "0%" beside a real figure reads as a bug.
                  percent: '${math.max(1, (slices[i].share * 100).round())}%',
                  amount: slices[i].outstanding.format(),
                ),
            ],
          ),
          if (slices.length == 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              // One slice is a bar at full width, which says nothing. Naming that
              // is better than drawing a chart that looks broken.
              'Everything outstanding is in one category.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// What falls due over the next six months.
class _MonthsAhead extends StatelessWidget {
  const _MonthsAhead({required this.outlook});

  final BillOutlook outlook;

  @override
  Widget build(BuildContext context) {
    final Money busiest = outlook.busiestMonth;
    final DateTime thisMonth = outlook.byMonth.first.month;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DashboardCardTitle(
            title: 'The months ahead',
            subtitle: 'Busiest is ${busiest.format()}',
          ),
          const SizedBox(height: AppSpacing.lg),
          MonthlyDueChart(
            bars: <MonthBar>[
              for (final MonthlyDue month in outlook.byMonth)
                MonthBar(
                  label: DateFormat.MMM().format(month.month),
                  amount: month.outstanding.format(),
                  fraction: busiest.minorUnits <= 0
                      ? 0
                      : month.outstanding.minorUnits / busiest.minorUnits,
                  isCurrent: month.month == thisMonth,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A labelled block of bills.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.count,
    required this.bills,
    required this.onOpen,
  });

  final String label;

  /// How many rows are under this heading.
  ///
  /// Redundant with the rows themselves for two or three, and not for eight —
  /// the point is knowing how far the section runs without scrolling it.
  final int count;

  final List<BillWithStatus> bills;
  final ValueChanged<BillWithStatus> onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '$count',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final BillWithStatus item in bills) ...<Widget>[
          BillListTile(item: item, onTap: () => onOpen(item)),
          if (item != bills.last) const SizedBox(height: AppSpacing.cardGap),
        ],
      ],
    );
  }
}

/// Everything past next week, counted rather than listed.
///
/// A row per bill for six weeks out turns the dashboard into the bills list. A
/// count and a figure say the same thing in one line, and the tap goes where the
/// rows actually live.
///
/// It names the soonest date as well, because when everything a user has falls
/// past next week this row is the *only* thing under the summary — and "2 more
/// bills later" on its own leaves them with no idea whether later means Tuesday
/// or March.
class _LaterSummary extends StatelessWidget {
  const _LaterSummary({required this.group, required this.onSeeAll});

  final UpcomingGroup group;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: colors.surface,
      borderRadius: AppRadii.panel,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSeeAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadii.xs),
                  ),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.bills.length == 1
                          ? '1 more bill later'
                          : '${group.bills.length} more bills later',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${group.total.format()} · from '
                      '${DateFormat.MMMd().format(group.bills.first.bill.dueOn)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bills exist, and none of them are waiting on anything.
class _AllClear extends StatelessWidget {
  const _AllClear({required this.hasOverdue});

  /// Changes what "clear" means: with something overdue above, this is only
  /// saying there is nothing *else*.
  final bool hasOverdue;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: AppRadii.panel,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: <Widget>[
            Icon(Icons.check_circle_rounded, color: colors.primary, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                hasOverdue
                    ? 'Nothing else coming up. Clear the ones above and you are done.'
                    : 'Nothing coming up. Everything is settled.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.primaryText,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
