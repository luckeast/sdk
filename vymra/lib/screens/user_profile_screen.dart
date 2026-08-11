import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/voice_text_field.dart';

/// User profile screen showing editable account information.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final ImageService _imageService = ImageService();
  File? _avatarPreviewFile;
  bool _didBootstrap = false;
  bool _hasNewAvatarSelection = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return AppLocalizations.of(context).tr('N/A');
    }
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _bootstrapProfile(String avatarPath, String username) async {
    _usernameController.text = username;
    _didBootstrap = true;

    final File? avatarFile = await _imageService.loadImage(avatarPath);
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarPreviewFile = avatarFile;
      _hasNewAvatarSelection = false;
    });
  }

  Future<void> _pickAvatar() async {
    final File? file = await _imageService.pickFromGallery();
    if (!mounted || file == null) {
      return;
    }

    setState(() {
      _avatarPreviewFile = file;
      _hasNewAvatarSelection = true;
    });
  }

  Future<void> _saveProfile() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) {
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Username cannot be empty.')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    String avatarPath = user.avatarPath;
    if (_avatarPreviewFile != null && _hasNewAvatarSelection) {
      if (user.avatarPath.isNotEmpty) {
        await _imageService.deleteImage(user.avatarPath);
      }
      avatarPath = await _imageService.saveImage(
        _avatarPreviewFile!,
        'user_avatars',
        user.userId,
      );
    }

    await authProvider.updateUserProfile(
      username: _usernameController.text,
      avatarPath: avatarPath,
    );

    if (mounted) {
      setState(() => _hasNewAvatarSelection = false);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('Profile updated.')),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (user != null && !_didBootstrap) {
      _bootstrapProfile(user.avatarPath, user.username);
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('My Profile'))),
      body: user == null
          ? Center(child: Text(context.tr('No active profile found.')))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      _avatarPreviewFile != null
                          ? Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: FileImage(_avatarPreviewFile!),
                                  fit: BoxFit.cover,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                            )
                          : UserAvatar(
                              avatarPath: user.avatarPath,
                              radius: 56,
                              iconSize: 52,
                            ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _pickAvatar,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.photo_camera_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(user.username, style: AppTextStyles.headline),
                  const SizedBox(height: 4),
                  Text(
                    context.tr(
                      'User ID: {userId}',
                      params: <String, String>{'userId': user.userId},
                    ),
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr('Profile Details'),
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: 16),
                        VoiceTextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: context.tr('Username'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : _saveProfile,
                          child: Text(
                            authProvider.isLoading
                                ? context.tr('Saving...')
                                : context.tr('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        _InfoRow(
                          label: context.tr('Account Created'),
                          value: _formatDateTime(user.createdAt),
                          icon: Icons.calendar_today,
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          label: context.tr('Last Login'),
                          value: _formatDateTime(user.lastLoginAt),
                          icon: Icons.access_time,
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          label: context.tr('Status'),
                          value: authProvider.isLoggedIn
                              ? context.tr('Active')
                              : context.tr('Offline'),
                          icon: Icons.circle,
                          valueColor: authProvider.isLoggedIn
                              ? AppColors.success
                              : AppColors.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
