import 'package:flutter/rendering.dart';

/// Corner radius tokens.
///
/// The reference design uses a small number of distinct radii and applies them
/// consistently: tight on chips, generous on cards, fully round on primary
/// actions and the bottom navigation.
abstract final class AppRadii {
  /// 8 — chips, meta pills, small tags.
  static const double xs = 8;

  /// 12 — inputs and compact cards.
  static const double sm = 12;

  /// 20 — list cards. The new reference rounds its cards noticeably more than
  /// the old one did.
  static const double md = 20;

  /// 24 — feature cards and summary panels.
  static const double lg = 24;

  /// 28 — bottom sheets and dialogs.
  static const double xl = 28;

  /// Fully rounded. Large enough to round any height PayPaw uses.
  static const double pill = 999;

  // --- Ready-made BorderRadius values --------------------------------------

  /// Chips and meta pills.
  static const BorderRadius chip = BorderRadius.all(Radius.circular(xs));

  /// Text fields and dropdowns.
  static const BorderRadius input = BorderRadius.all(Radius.circular(sm));

  /// List cards.
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));

  /// Feature and summary cards.
  static const BorderRadius panel = BorderRadius.all(Radius.circular(lg));

  /// Bottom sheets — top corners only.
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );

  /// Primary buttons and the bottom navigation bar.
  static const BorderRadius round = BorderRadius.all(Radius.circular(pill));
}
