import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';

/// A centred spinner, with an optional line of text.
///
/// Use it for a first load with nothing to show yet. Prefer `AppSkeleton` when
/// the shape of what is coming is already known — a skeleton list tells the user
/// what to expect, where a spinner only says "wait".
///
/// Do not use it for a save or a submit: that belongs inside the button, via
/// `AppPrimaryButton(isBusy: true)`, so the rest of the screen stays usable and
/// in place.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({this.label, super.key});

  /// Optional line under the spinner. Worth adding only when the wait is
  /// expected to be long enough that silence would feel broken.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (label case final String text) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
