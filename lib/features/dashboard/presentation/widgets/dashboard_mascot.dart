import 'package:flutter/material.dart';

/// The shiba peeking over the top of a card.
///
/// ## How it is positioned, and why not with a negative offset
///
/// The obvious build is a `Stack` with the artwork at a negative `top` and
/// `Clip.none`, so it spills upward out of the card. That works and then hits
/// the greeting: the dashboard is a `ListView`, a child that overflows its own
/// bounds paints over its *sibling*, and the ears would land on "Good afternoon"
/// on a short screen and not on a tall one.
///
/// So the space is **reserved** instead. This widget is as tall as the card plus
/// the overhang, the card is padded down into it, and the artwork sits in the gap
/// that padding created. Nothing overflows anything, the greeting keeps its
/// distance at every size, and the whole block measures honestly for the
/// scrollable it lives in.
///
/// ## Why the overhang is computed rather than a constant
///
/// The artwork is sized as a fraction of the card's width so it holds its
/// proportion from a 320dp phone to a tablet. Its height therefore changes with
/// the width, and a fixed overhang would leave the paws floating above the card
/// on a wide screen and buried in it on a narrow one.
class DashboardMascot extends StatelessWidget {
  const DashboardMascot({required this.child, super.key});

  /// The card the mascot leans on.
  final Widget child;

  /// How wide the artwork is, as a fraction of the available width.
  ///
  /// Roughly two thirds, which is what the reference shows: wide enough for the
  /// ears and the two little flourishes to read, narrow enough that it is
  /// clearly sitting *on* the card rather than being a banner above it.
  static const double _widthFraction = 0.74;

  /// The source image's width over its height. 1379 × 1141.
  ///
  /// Named rather than left to `Image` to work out, because the layout has to
  /// know the rendered height *before* the image decodes — otherwise the card
  /// jumps down the moment it loads.
  static const double _aspectRatio = 1379 / 1141;

  /// Where the paws actually are, as a fraction of the frame's height.
  ///
  /// The PNG has transparent space below the paws and the peso tag. Positioning
  /// by the frame's bottom edge would leave a visible gap between the paws and
  /// the card they are supposed to be resting on, so the maths uses this instead.
  static const double _pawLine = 0.925;

  /// How far the paws come down over the card's top edge.
  static const double _overlap = 20;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth * _widthFraction;
        final double height = width / _aspectRatio;

        // The card starts here: far enough down that the paws land [_overlap]
        // inside it.
        final double cardTop = (height * _pawLine) - _overlap;

        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: cardTop),
              child: child,
            ),
            // Above the card in paint order, so the paws and the tag sit over
            // its surface rather than under it.
            Positioned(
              top: 0,
              child: Image.asset(
                'assets/images/paypaw_hero_mascot.png',
                width: width,
                height: height,
                // The artwork is the whole point of the widget; a missing asset
                // should be a blank space rather than a red box across the
                // dashboard, and the card below it still says everything the
                // screen needs.
                errorBuilder: (_, _, _) =>
                    SizedBox(width: width, height: height),
              ),
            ),
          ],
        );
      },
    );
  }
}
