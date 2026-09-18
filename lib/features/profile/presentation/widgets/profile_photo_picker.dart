import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Profile avatar picker widget supporting image preview, loading state, and removal.
/// Universal Engineering Rule #10: Secure photo handling and size limits.
class ProfilePhotoPicker extends StatelessWidget {
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback onPickPhoto;
  final VoidCallback onRemovePhoto;

  const ProfilePhotoPicker({
    super.key,
    this.avatarUrl,
    required this.isUploading,
    required this.onPickPhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 2.0,
                  ),
                  image: hasAvatar && !avatarUrl!.startsWith('http')
                      ? null
                      : (hasAvatar
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: !hasAvatar
                    ? const Icon(
                        Icons.person_outline,
                        size: 52,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              if (isUploading)
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withAlpha(100),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: isUploading ? null : onPickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.backgroundDark : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: isUploading ? null : onPickPhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: Text(
                  hasAvatar ? 'Change Photo' : 'Upload Photo',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              if (hasAvatar) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isUploading ? null : onRemovePhoto,
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
