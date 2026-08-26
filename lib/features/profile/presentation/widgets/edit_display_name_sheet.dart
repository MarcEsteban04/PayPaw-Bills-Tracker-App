import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_button.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/user_profile.dart';
import '../controllers/profile_providers.dart';

/// What this person would like to be called.
///
/// A sheet rather than a screen: it is one field, and pushing a route for one
/// field puts a back arrow, a title bar and a transition between somebody and a
/// twenty-character edit.
///
/// ## Clearing it is a choice, not an error
///
/// An empty field saves as null and the account goes back to being nameless.
/// That is a thing somebody might genuinely want, and refusing it — insisting on
/// a name once one has been given — would be the app deciding it knows better.
Future<void> showEditDisplayNameSheet({
  required BuildContext context,
  required String? name,
}) => showAppBottomSheet<void>(
  context: context,
  title: 'Your name',
  child: _EditDisplayName(name: name),
);

class _EditDisplayName extends ConsumerStatefulWidget {
  const _EditDisplayName({required this.name});

  final String? name;

  @override
  ConsumerState<_EditDisplayName> createState() => _EditDisplayNameState();
}

class _EditDisplayNameState extends ConsumerState<_EditDisplayName> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isSaving = ref.watch(profileControllerProvider).isSaving;

    // Reported here rather than swallowed. This is a write the user asked for
    // and is watching; a name that appears to save and did not is worse than a
    // message, because the next thing they do is close the sheet believing it.
    ref.listen<ProfileEditState>(profileControllerProvider, (
      ProfileEditState? previous,
      ProfileEditState next,
    ) {
      if (next.errorMessage case final String message
          when message != previous?.errorMessage) {
        showAppToast(context, message: message, tone: AppToastTone.error);
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: _controller,
          hint: 'What should PayPaw call you?',
          autofocus: true,
          enabled: !isSaving,
          textInputAction: TextInputAction.done,
          // The column's own check is 80 characters, so the field stops there
          // rather than letting the database refuse what was typed.
          maxLength: UserProfile.nameMaxLength,
          onFieldSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Used to greet you, and nowhere else. Leave it empty to go back to '
          'your email address.',
          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: 'Save',
          isBusy: isSaving,
          onPressed: isSaving ? null : _save,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final String typed = _controller.text.trim();

    final bool saved = await ref
        .read(profileControllerProvider.notifier)
        // Empty saves as null. See the note above: a name of zero characters is
        // a request to have none, not a request for the empty string.
        .saveDisplayName(typed.isEmpty ? null : typed);

    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }
}
