import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/pet_media_asset.dart';
import '../providers/pet_profile_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';

/// Full album browser for pet photos and imported AI assets.
class PetAlbumScreen extends StatelessWidget {
  const PetAlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<PetMediaAsset> entries =
        (context.watch<PetProfileProvider>().profile?.albumEntries.toList() ??
            <PetMediaAsset>[])
          ..sort(
        (PetMediaAsset a, PetMediaAsset b) => b.createdAt.compareTo(a.createdAt),
      );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pet Album'))),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr(
                    'No album moments yet. Add photos from camera, gallery, AI Scan, or AI Time.',
                  ),
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: entries.length,
              itemBuilder: (BuildContext context, int index) {
                final PetMediaAsset asset = entries[index];
                return _AlbumTile(asset: asset);
              },
            ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final PetMediaAsset asset;

  const _AlbumTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final DateFormat format = DateFormat('MMM d');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _AlbumPreviewScreen(asset: asset),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryDark.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: _StoredImage(
                  relativePath: asset.relativePath,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: AppColors.primary.withOpacity(0.12),
                    child: const Center(
                      child: Icon(Icons.photo, color: AppColors.primary, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _SourceBadge(source: asset.source),
                      const Spacer(),
                      Text(
                        format.format(asset.createdAt),
                        style: AppTextStyles.label,
                      ),
                    ],
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

class _AlbumPreviewScreen extends StatelessWidget {
  final PetMediaAsset asset;

  const _AlbumPreviewScreen({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(asset.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: _StoredImage(
              relativePath: asset.relativePath,
              fit: BoxFit.contain,
              placeholder: Container(
                color: Colors.white12,
                child: const Center(
                  child: Icon(Icons.photo, color: Colors.white, size: 52),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final MapEntry<Color, String> presentation = switch (source) {
      'camera' => MapEntry(AppColors.primary, context.tr('Camera')),
      'gallery' => MapEntry(AppColors.secondary, context.tr('Gallery')),
      'ai_scan' => MapEntry(AppColors.accent, context.tr('AI Scan')),
      'ai_time' => MapEntry(AppColors.error, context.tr('AI Time')),
      _ => MapEntry(AppColors.textSecondary, context.tr('Saved')),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: presentation.key.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        presentation.value,
        style: AppTextStyles.label.copyWith(
          color: presentation.key,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StoredImage extends StatelessWidget {
  final String relativePath;
  final Widget placeholder;
  final BoxFit fit;

  const _StoredImage({
    required this.relativePath,
    required this.placeholder,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: ImageService().loadImage(relativePath),
      builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
        final File? file = snapshot.data;
        if (file == null) {
          return placeholder;
        }

        return Image.file(file, fit: fit, width: double.infinity, height: double.infinity);
      },
    );
  }
}
