import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/presentation/widgets/app_bottom_sheet.dart';
import '../../../../core/presentation/widgets/app_toast.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../controllers/profile_providers.dart';

/// Where a profile picture comes from.
///
/// ## Downscaled before it leaves the phone
///
/// 512 by 512 at quality 85, which lands a photograph in tens of kilobytes. The
/// bucket's 2 MB limit is a backstop against a bug, not the size anything is
/// meant to be — an avatar is drawn at 72dp and uploading four megapixels for it
/// costs the user's data allowance and nothing else.
///
/// ## Gallery and camera, no permissions
///
/// `image_picker` reaches the gallery through Android's photo picker and the
/// camera through an intent to the camera app, so neither needs a runtime
/// permission or a manifest entry. Declaring `CAMERA` would put a permission on
/// the Play listing for a capability the app never uses directly.
Future<void> showAvatarPickerSheet({
  required BuildContext context,
  required bool hasPicture,
}) => showAppBottomSheet<void>(
  context: context,
  title: 'Profile picture',
  child: _AvatarPicker(hasPicture: hasPicture),
);

class _AvatarPicker extends ConsumerWidget {
  const _AvatarPicker({required this.hasPicture});

  final bool hasPicture;

  /// The longest edge an uploaded picture keeps.
  static const double _maxEdge = 512;

  /// JPEG quality after downscaling.
  static const int _quality = 85;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isSaving = ref.watch(profileControllerProvider).isSaving;

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
        _Option(
          icon: Icons.photo_library_outlined,
          label: 'Choose from your photos',
          enabled: !isSaving,
          onTap: () => _pick(context, ref, ImageSource.gallery),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Option(
          icon: Icons.photo_camera_outlined,
          label: 'Take a photo',
          enabled: !isSaving,
          onTap: () => _pick(context, ref, ImageSource.camera),
        ),
        if (hasPicture) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _Option(
            icon: Icons.delete_outline_rounded,
            label: 'Remove picture',
            enabled: !isSaving,
            isDestructive: true,
            onTap: () => _remove(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    ImageSource source,
  ) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge,
      maxHeight: _maxEdge,
      imageQuality: _quality,
    );

    // Null is a cancel, not a failure. Nothing to report.
    if (picked == null || !context.mounted) {
      return;
    }

    final Uint8List bytes = await picked.readAsBytes();

    if (!context.mounted) {
      return;
    }

    final bool saved = await ref
        .read(profileControllerProvider.notifier)
        .saveAvatar(
          bytes: bytes,
          // What the picker says, or JPEG — which is what `imageQuality`
          // re-encodes to anyway. The bucket checks this against its allowed
          // types, so a wrong guess is a refused upload rather than a bad file.
          contentType: picked.mimeType ?? 'image/jpeg',
        );

    if (saved && context.mounted) {
      // The path has not changed, so the old signed URL would still be cached
      // against it. A fresh URL is what makes the new picture appear.
      ref.invalidate(avatarUrlProvider);
      Navigator.of(context).pop();
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final bool removed = await ref
        .read(profileControllerProvider.notifier)
        .removeAvatar();

    if (removed && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette colors = context.colors;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Color foreground = switch ((enabled, isDestructive)) {
      (false, _) => colors.onDisabled,
      (true, true) => colors.overdueText,
      (true, false) => colors.textPrimary,
    };

    return Material(
      color: colors.surfaceMuted,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: textTheme.bodyLarge?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
