/// Spacing scale, in logical pixels.
///
/// A 4-point scale, because every gap measured in the reference design lands on
/// a multiple of 4. Using the scale instead of loose numbers is what keeps
/// rhythm consistent across screens built in different sprints.
///
/// Reach for the semantic values at the bottom when one applies — they say
/// *why* a gap is that size, which a bare `lg` does not.
abstract final class AppSpacing {
  /// 2 — hairline separation, icon-to-label in dense chips.
  static const double xxs = 2;

  /// 4 — tight pairing.
  static const double xs = 4;

  /// 8 — default gap between related elements.
  static const double sm = 8;

  /// 12 — gap between cards in a list.
  static const double md = 12;

  /// 16 — screen padding and card padding in the reference.
  static const double lg = 16;

  /// 20 — roomier card padding.
  static const double xl = 20;

  /// 24 — gap between sections.
  static const double xxl = 24;

  /// 32 — major separation.
  static const double xxxl = 32;

  /// 40 — top of screen to first element on sparse screens.
  static const double huge = 40;

  // --- Semantic aliases -----------------------------------------------------

  /// Horizontal inset from the screen edge to content.
  static const double screenInset = lg;

  /// Inner padding of a card.
  static const double cardInset = lg;

  /// Vertical gap between cards in a scrolling list.
  static const double cardGap = md;

  /// Vertical gap between one section and the next.
  static const double sectionGap = xxl;

  /// Extra bottom padding at the foot of a scrolling screen.
  ///
  /// It was 96 — enough for a scroll view's last item to clear a navigation bar
  /// that floated *over* the page. The shell stops the body extending under the
  /// bar now, so the bar reserves its own space and this no longer has to. What
  /// is left is breathing room, so the last card does not sit flush against the
  /// navigation.
  ///
  /// Kept under its old name because that is still what it is for; only the
  /// mechanism changed.
  static const double bottomNavClearance = xl;
}
