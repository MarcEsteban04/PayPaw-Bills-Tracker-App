import 'package:flutter/painting.dart';

/// Shadow tokens.
///
/// The reference design uses wide, very soft, almost colourless shadows — cards
/// read as lifted off the peach canvas rather than outlined. Material's default
/// `elevation` shadows are tighter and darker than that, so PayPaw paints these
/// explicitly and keeps component elevation at zero.
///
/// Alpha is baked into each colour so the lists stay `const`.
abstract final class AppShadows {
  /// Barely-there lift: chips, inline controls, pressed states.
  static const List<BoxShadow> subtle = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// The default card shadow.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 20, offset: Offset(0, 4)),
  ];

  /// Elements floating above content: the bottom navigation, sheets, menus.
  static const List<BoxShadow> floating = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 28, offset: Offset(0, 10)),
  ];

  /// The warm glow under the reference's primary CTA. Orange rather than black,
  /// which is what stops the button looking pasted onto the page.
  static const List<BoxShadow> primaryGlow = <BoxShadow>[
    BoxShadow(color: Color(0x40F26B21), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
