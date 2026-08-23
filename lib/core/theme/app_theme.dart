import 'package:flutter/material.dart';

/// PayPaw's Material theme.
///
/// **Placeholder.** This exists so the app has a coherent theme to run with
/// during Phase 1. The real design system — colour, type, spacing and shape
/// tokens taken from `design/app_ref_design/` — is built in Phase 2 (Sprints
/// 6-10) and will replace the body of this class.
///
/// Only the seed colour below is meaningful today: it is the orange accent
/// sampled from the reference design, so early screens are not built against a
/// palette that is about to change wholesale.
abstract final class AppTheme {
  /// Orange accent from the reference design. Approximate — sampled from a
  /// lossy image, to be confirmed when design tokens are locked in Sprint 6.
  static const Color _seed = Color(0xFFF26B21);

  /// Light theme. PayPaw's reference design is light-only; a dark theme is
  /// added alongside the design system.
  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );
}
