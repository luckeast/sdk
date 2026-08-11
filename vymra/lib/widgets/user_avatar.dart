import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_service.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatefulWidget {
  final String avatarPath;
  final double radius;
  final double iconSize;

  const UserAvatar({
    super.key,
    required this.avatarPath,
    this.radius = 34,
    this.iconSize = 34,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  final ImageService _imageService = ImageService();
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarPath != widget.avatarPath) {
      _loadAvatar();
    }
  }

  Future<void> _loadAvatar() async {
    if (widget.avatarPath.isEmpty) {
      if (mounted) {
        setState(() => _avatarFile = null);
      }
      return;
    }

    final File? avatarFile = await _imageService.loadImage(widget.avatarPath);
    if (!mounted) {
      return;
    }

    setState(() => _avatarFile = avatarFile);
  }

  @override
  Widget build(BuildContext context) {
    final double diameter = widget.radius * 2;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: _avatarFile != null
            ? Image.file(_avatarFile!, fit: BoxFit.cover)
            : Icon(Icons.person, size: widget.iconSize, color: Colors.white),
      ),
    );
  }
}
