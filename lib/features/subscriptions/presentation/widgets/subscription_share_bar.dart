import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/entities/subscription_spend.dart';
import 'subscription_mark.dart';

/// Where the monthly total actually goes, as one bar.
///
/// ## Why a picture and not another sentence
///
/// The card already said "₱1,847 a month" and "Dearest is Adobe". Both are true
/// and neither answers the question somebody opens this screen with, which is
/// **"what is eating it"** — and that answer is a proportion, not a number. Told
/// that Adobe is the dearest, a reader still has to divide to find out whether
/// it is a third of the bill or nine tenths of it.
///
/// One bar, split by what each service costs, in each service's own colour. It
/// is the same information as the rows below, arranged so it can be read in a
/// glance instead of totted up.
///
/// ## Segments below a threshold are pooled
///
/// A subscription worth two per cent of the total renders as a sliver too thin
/// to see and too thin to tap, and a dozen of them turn the bar into a smear.
/// Everything under [_minShare] is collected into one muted remainder at the
/// end, which is honest — the bar still sums to the whole — and legible.
class SubscriptionShareBar extends StatelessWidget {
  const SubscriptionShareBar({required this.spend, super.key});

  final SubscriptionSpend spend;

  /// The smallest slice worth drawing on its own.
  static const double _minShare = 0.06;

  static const double _height = 10;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;

    final int total = spend.ranked.fold<int>(
      0,
      (int sum, Subscription each) =>
          sum + SubscriptionSpend.monthlyCostOf(each).minorUnits,
    );

    // Nothing to divide. A bar of one colour says less than the figure above it
    // already did.
    if (total <= 0 || spend.ranked.length < 2) {
      return const SizedBox.shrink();
    }

    final List<_Slice> slices = <_Slice>[];
    int pooled = 0;

    for (final Subscription each in spend.ranked) {
      final int cost = SubscriptionSpend.monthlyCostOf(each).minorUnits;
      final double share = cost / total;

      if (share < _minShare) {
        pooled += cost;
      } else {
        slices.add(
          _Slice(
            share: share,
            color: SubscriptionMarks.colorFor(each.details.provider),
          ),
        );
      }
    }

    if (pooled > 0) {
      slices.add(_Slice(share: pooled / total, color: colors.border));
    }

    return ClipRRect(
      borderRadius: AppRadii.chip,
      child: SizedBox(
        height: _height,
        child: Row(
          // Stretch, and it is safe here precisely because the height above is
          // bounded. Without it the row centres its children, and a `ColoredBox`
          // with no child has no intrinsic height — so every segment collapsed
          // to nothing and the bar rendered as a gap.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (int index, _Slice slice) in slices.indexed) ...<Widget>[
              if (index > 0)
                // A hairline of the card's own colour between segments. Without
                // it two adjacent hues of similar weight read as one block, and
                // the bar undercounts.
                Container(width: 2, color: colors.surface),
              Expanded(
                // Rounded to a whole so the flex factors stay integers, and
                // scaled up first so a six-per-cent slice is not rounded to
                // nothing.
                flex: (slice.share * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: slice.color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Slice {
  const _Slice({required this.share, required this.color});

  final double share;
  final Color color;
}
