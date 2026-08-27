import 'package:flutter/material.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/dashboard_mood.dart';

/// The hero card's interior: the figures, the ring, and the mascot holding it.
///
/// ## Why this owns the layout rather than the card
///
/// The three pieces overlap. The ring is drawn across the mascot's raised paw,
/// and the mascot reaches the card's outer edge — past the padding everything
/// else respects. A `Row` cannot express any of that, so the card is handed zero
/// padding and this places all three.
///
/// ## The mascot changes with the news
///
/// Which artwork appears is [DashboardMood]'s decision, made from the totals, and
/// the file is named after the mood. Adding a variant is a PNG dropped into
/// `assets/images/mascots/` under the matching name — the directory is declared
/// in `pubspec.yaml` rather than the files, precisely so that is the whole job.
///
/// A mood whose artwork has not been drawn yet falls back to the one that has.
/// The alternative is a hole where the mascot should be, on the app's first
/// screen, because a file was not copied.
class DashboardHeroBody extends StatelessWidget {
  const DashboardHeroBody({
    required this.mood,
    required this.figures,
    required this.ring,
    required this.footnote,
    super.key,
  });

  /// Which mascot to show.
  final DashboardMood mood;

  /// The label and the outstanding figure, top left.
  final Widget figures;

  /// Builds the progress ring at the diameter this layout has room for, or null
  /// when there is no denominator to show one for.
  ///
  /// A builder rather than a widget, because the diameter is this card's
  /// decision — it is derived from the card's own height, and the caller has no
  /// way to know it. Handing in a finished ring is what left a fixed 96 sitting
  /// in a card that is 147 tall on a phone and 300 on a tablet.
  final Widget Function(double diameter)? ring;

  /// The line under the ring, bottom left. Null when there is nothing to say.
  final Widget? footnote;

  /// The card's base height over its width, taken from the reference.
  ///
  /// Driven by the width so the mascot keeps its proportion from a 320dp phone
  /// to a tablet — a fixed height would leave it small in a wide card and
  /// cramped in a narrow one. Base rather than final: the text scale stretches
  /// it further, see [build].
  static const double _heightRatio = 0.545;

  /// The mascot's height, as a fraction of the card's base height.
  static const double _mascotHeight = 1;

  /// The width of the box the mascot is drawn into, over its height.
  ///
  /// Named rather than measured from the image, and it is a *box* rather than
  /// the artwork's own ratio for two reasons.
  ///
  /// The ring's position is derived from this width, and the layout has to
  /// settle before the image decodes — measuring the artwork would jump the ring
  /// sideways when it loaded.
  ///
  /// And it can be one constant because the artwork is normalised to it. The
  /// four source drawings arrive at four different sizes with four different
  /// amounts of transparent margin — the sitting pose had 15% of empty canvas
  /// down its left side and 2% under its feet, which is why it floated off the
  /// card's corner instead of sitting on it. Each is cropped to its ink and
  /// pinned to the bottom-right of a shared 1200 × 1300 frame, so every pose
  /// touches the same two edges and this one number holds for all of them.
  static const double _mascotAspect = 1200 / 1300;

  /// How far the ring's right edge sits inside the mascot's left edge, as a
  /// fraction of the mascot's width.
  ///
  /// This is what puts the paw on the ring. Anchored to the mascot rather than
  /// to the card, so the two stay together at every width.
  ///
  /// Set so the ring's *centre* — where the reading is — stays clear of the
  /// mascot's box. The ring is painted over the dog, so the track survives
  /// either way; the percentage in the hole does not. The poses are not equally
  /// polite about it: the sitting one is narrow where the ring is, while the
  /// leaping and cheering ones put a whole flank behind the reading and left it
  /// black-on-orange. Only the paw and the forearm should reach the dial.
  static const double _ringOverlap = 0.72;

  /// The ring's diameter, as a fraction of the card's base height.
  ///
  /// Proportional rather than the widget's own fixed 96, because everything else
  /// in this card is: a constant diameter is a third of a phone-width card and a
  /// tenth of a tablet one, so the same layout would be crowded on one and lost
  /// on the other.
  static const double _ringSize = 0.58;

  /// How far the ring sits off the card's floor, as a fraction of that height.
  ///
  /// Low, and deliberately lower than the text's own padding. The mascot stands
  /// on the bottom edge, and a dial floating well above the feet it is being
  /// held next to reads as two drawings rather than one.
  static const double _ringFloor = 0.06;

  /// How wide the figures are allowed to be, as a fraction of the card.
  ///
  /// Bounded rather than `Expanded`, because the ring is placed absolutely and
  /// would not push them: an unbounded figure would run under the ring and read
  /// as a rendering fault. `_Figures` scales its number down to fit, so a bound
  /// is enough — it does not need to be generous.
  static const double _figuresWidth = 0.40;

  /// The same for the footnote, and tighter — because it sits lower.
  ///
  /// The figures are at the card's top, level with the ring's thin upper arc,
  /// where a few spare pixels cost nothing. The footnote is at the bottom, level
  /// with the ring's widest point, so the same bound would put the end of that
  /// line underneath the dial. Two numbers rather than one because the
  /// obstruction is a circle, and a circle is not the same width all the way
  /// down.
  static const double _footnoteWidth = 0.30;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;

        // A floor, not a height. The mascot needs a fixed-aspect canvas, but a
        // shape derived only from the width cannot grow for somebody who has
        // turned their text up — at 2x the figures overflowed it by a hundred
        // pixels. Scaling the canvas by the text scale is not the fix either:
        // the text does not grow linearly, because at some point the label and
        // the footnote start wrapping, so any multiplier is wrong somewhere.
        //
        // So the text sets the height whenever it needs more than the drawing
        // does, and the drawing keeps the base. A mascot scaled to 2x on a 320dp
        // phone would be wider than the card and would cover the number it is
        // reacting to, which is not a bigger version of this card — it is a
        // different one.
        final double base = width * _heightRatio;
        final double mascotHeight = base * _mascotHeight;
        final double mascotWidth = mascotHeight * _mascotAspect;

        return ClipRRect(
          // The card sets no clip of its own — `Material` defaults to
          // `Clip.none` — and the mascot reaches the card's edge, so without
          // this its tail would paint outside the rounded corner.
          borderRadius: AppRadii.card,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: base, minWidth: width),
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _Mascot(
                    mood: mood,
                    width: mascotWidth,
                    height: mascotHeight,
                  ),
                ),

                // Over the mascot, not under it. Painting the dog on top was
                // meant to read as a paw resting on the dial; what it actually
                // read as was a dog standing in front of one, because the arm
                // cut the ring in half and the two stopped being one object. The
                // ring in front puts its track across the forearm, which is what
                // holding something looks like.
                if (ring case final Widget Function(double) dial)
                  Positioned(
                    right: mascotWidth * _ringOverlap,
                    bottom: base * _ringFloor,
                    child: dial(base * _ringSize),
                  ),

                // The one child the stack measures, so the card grows when the
                // words do. Everything else is positioned and contributes
                // nothing to the height.
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(width: width * _figuresWidth, child: figures),
                      // Kept with the number rather than pushed to the card's
                      // floor. It is a sub-line of that figure — parked at the
                      // bottom it read as a separate thought, and left a band of
                      // empty card between the two that the eye had to cross.
                      if (footnote case final Widget line) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(width: width * _footnoteWidth, child: line),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The artwork for one mood, falling back when it does not exist yet.
class _Mascot extends StatelessWidget {
  const _Mascot({
    required this.mood,
    required this.width,
    required this.height,
  });

  final DashboardMood mood;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      mood.assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      // Every pose stands on the card's bottom-right corner, whatever its own
      // proportions leave over inside the box. Centred — the default — a taller
      // drawing would float inward and sit differently from its neighbours.
      alignment: Alignment.bottomRight,
      // A mood whose artwork has not been drawn falls back to the one that
      // always exists, rather than leaving a hole on the app's first screen.
      // The fallback is deliberately the neutral face: a missing "all settled"
      // should not resolve to the overdue one.
      errorBuilder: (_, _, _) => Image.asset(
        DashboardMood.noneSettled.assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.bottomRight,
        errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
      ),
    );
  }
}
