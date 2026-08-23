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

  /// Extra bottom padding so a scroll view clears the floating bottom
  /// navigation instead of ending underneath it.
  static const double bottomNavClearance = 96;
}
