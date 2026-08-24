import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../layout/app_breakpoints.dart';

/// What a toast is reporting.
enum AppToastTone {
  /// It worked.
  success,

  /// It did not.
  error,

  /// Neither — 'Archived', 'Copied'.
  info,
}

/// Shows a message at the top of the screen.
///
/// ## Why not a `SnackBar`
///
/// A snackbar lands at the bottom, which on this app is where the floating
/// navigation bar and the add button already are — so every message either
/// covered them or shoved them upward. It is also owned by the nearest
/// `ScaffoldMessenger`, so a message raised from inside a bottom sheet went to
/// the sheet's messenger and vanished with it. That is exactly when the
/// interesting messages are raised: a delete confirmed from a drawer, a save from
/// a form that closes itself.
///
/// This goes into the **root overlay** instead. It outlives the sheet that
/// triggered it, sits above everything including dialogs, and reaches for the one
/// part of the screen nothing else uses.
///
/// ## One at a time
///
/// A new toast replaces the current one rather than queueing behind it. Messages
/// here are reports on something the user just did; a queue would show them the
/// answer to a question they had stopped asking.
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastTone tone = AppToastTone.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  OverlayState? overlay,
}) {
  // The root overlay, not the nearest one. A sheet's overlay is torn down with
  // the sheet, taking any message raised from inside it.
  //
  // [overlay] is for callers that have no context *below* the navigator — a
  // listener wrapping `MaterialApp` can reach the navigator by key, but the
  // overlay is that navigator's child, so looking upward from it finds nothing.
  final OverlayState? target =
      overlay ?? Overlay.maybeOf(context, rootOverlay: true);
  if (target == null) {
    return;
  }

  _AppToastHost.instance.show(
    overlay: target,
    message: message,
    tone: tone,
    actionLabel: actionLabel,
    onAction: onAction,
    // An action needs long enough to be read and reached. Without one the
    // message is a receipt, and lingering is just something in the way.
    duration: actionLabel == null
        ? duration
        : duration + const Duration(seconds: 2),
  );
}

/// Removes the toast on screen, if there is one.
void hideAppToast() => _AppToastHost.instance.hide();

/// Owns the single entry, so a second toast can replace the first.
class _AppToastHost {
  _AppToastHost._();

  static final _AppToastHost instance = _AppToastHost._();

  OverlayEntry? _entry;

  /// Bumped on every show. The exit animation removes an entry only if this has
  /// not moved on — otherwise a toast being replaced would remove its successor
  /// as it finished dying.
  int _generation = 0;

  void show({
    required OverlayState overlay,
    required String message,
    required AppToastTone tone,
    required String? actionLabel,
    required VoidCallback? onAction,
    required Duration duration,
  }) {
    hide();

    final int generation = ++_generation;
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (BuildContext context) => _Toast(
        message: message,
        tone: tone,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onDismissed: () {
          if (_generation == generation) {
            _entry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);
  }

  void hide() {
    if (_entry case final OverlayEntry entry when entry.mounted) {
      entry.remove();
    }
    _entry = null;
  }
}

/// The pill itself.
///
/// Shaped after the navigation bar's dark pill rather than inventing a second
/// floating language: same surface, same full rounding, same shadow. The app
/// already says "this floats above the page" one way.
class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  final String message;
  final AppToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 240),
  );

  /// Overshoots slightly on the way in and does not on the way out.
  ///
  /// The overshoot is what makes it read as arriving rather than appearing —
  /// borrowed from the way a dynamic island stretches. Reversed, an elastic curve
  /// would look like the toast was reluctant to leave, so the exit is plain.
  late final Animation<double> _entrance = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  bool _leaving = false;

  /// Held so it can be cancelled.
  ///
  /// An uncancelled `Future.delayed` is a pending timer, and a widget test that
  /// ends while one is outstanding fails on it — which is the right complaint:
  /// the callback would have fired into a disposed tree.
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_leaving || !mounted) {
      return;
    }
    _leaving = true;
    _timer?.cancel();

    await _controller.reverse();

    if (mounted) {
      widget.onDismissed();
    }
  }

  void _act() {
    widget.onAction?.call();
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final MediaQueryData media = MediaQuery.of(context);

    return Positioned(
      // Below the status bar, not under it. `viewPadding` rather than `padding`
      // so the position does not jump when a keyboard changes the insets.
      top: media.viewPadding.top + AppSpacing.sm,
      left: AppSpacing.screenInset,
      right: AppSpacing.screenInset,
      child: SafeArea(
        bottom: false,
        child: Align(
          child: ConstrainedBox(
            // Capped so it stays a pill on a tablet instead of stretching into a
            // banner across the whole width.
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) => Opacity(
                opacity: _fade.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  // Slides down from just above its resting place. The distance
                  // is small on purpose: a long slide reads as a page transition.
                  offset: Offset(0, -28 * (1 - _entrance.value)),
                  child: child,
                ),
              ),
              child: _Pill(
                message: widget.message,
                tone: widget.tone,
                actionLabel: widget.actionLabel,
                onAction: widget.onAction == null ? null : _act,
                onDismiss: _dismiss,
                colors: colors,
                textTheme: textTheme,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.message,
    required this.tone,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
    required this.colors,
    required this.textTheme,
  });

  final String message;
  final AppToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final AppPalette colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Dismissible(
        // Swipe up to send it away, which is where it came from. The key is
        // constant because there is only ever one.
        key: const ValueKey<String>('app-toast'),
        direction: DismissDirection.up,
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: colors.navSurface,
          borderRadius: AppRadii.round,
          elevation: 8,
          shadowColor: colors.shadowFloating,
          child: InkWell(
            // Tapping anywhere sends it away, so a message covering something is
            // never something to wait out.
            onTap: onAction == null ? onDismiss : null,
            borderRadius: AppRadii.round,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Badge(tone: tone, colors: colors),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      message,
                      // Two lines, then ellipsis. A toast that grows to five is a
                      // dialog that forgot to ask.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textOnDark,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (actionLabel case final String label) ...<Widget>[
                    const SizedBox(width: AppSpacing.md),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.navActivePill,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        minimumSize: const Size(0, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(label),
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

/// The coloured disc that carries the meaning before the words are read.
///
/// A shape as well as a colour, so the difference between "saved" and "could not
/// save" does not depend on telling green from red.
class _Badge extends StatelessWidget {
  const _Badge({required this.tone, required this.colors});

  final AppToastTone tone;
  final AppPalette colors;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color background) = switch (tone) {
      AppToastTone.success => (Icons.check_rounded, colors.primary),
      AppToastTone.error => (Icons.priority_high_rounded, colors.overdue),
      AppToastTone.info => (
        Icons.info_outline_rounded,
        colors.textOnDark.withValues(alpha: 0.16),
      ),
    };

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: colors.textOnDark),
    );
  }
}
