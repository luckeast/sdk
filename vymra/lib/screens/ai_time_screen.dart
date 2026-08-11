import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/pet_media_asset.dart';
import '../models/pet_profile.dart';
import '../providers/pet_profile_provider.dart';
import '../services/ai_consent_service.dart';
import '../services/doubao_ai_service.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/voice_text_field.dart';

/// Creative image studio that turns a pet photo and keywords into a themed poster.
class AiTimeScreen extends StatefulWidget {
  final String petId;

  const AiTimeScreen({super.key, required this.petId});

  @override
  State<AiTimeScreen> createState() => _AiTimeScreenState();
}

class _AiTimeScreenState extends State<AiTimeScreen> {
  final ImageService _imageService = ImageService();
  final DoubaoAiService _aiService = DoubaoAiService();
  final AiConsentService _consentService = AiConsentService();
  final TextEditingController _keywordsController = TextEditingController();

  File? _sourceImage;
  _PosterRecipe? _recipe;
  Uint8List? _generatedImageBytes;
  bool _isGenerating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvatarAsDefault();
    });
  }

  @override
  void dispose() {
    _keywordsController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatarAsDefault() async {
    final PetProfile? profile = context.read<PetProfileProvider>().profile;
    if (profile == null || profile.avatarPath.isEmpty) {
      return;
    }

    final File? avatarFile = await _imageService.loadImage(profile.avatarPath);
    if (!mounted || avatarFile == null) {
      return;
    }

    setState(() {
      _sourceImage = avatarFile;
      _recipe = _buildRecipe(_keywordsController.text, profile.name);
    });
  }

  Future<void> _pickPhoto(ImageSourceType source) async {
    final File? file = switch (source) {
      ImageSourceType.camera => await _imageService.captureImage(),
      ImageSourceType.gallery => await _imageService.pickFromGallery(),
    };

    if (file == null) {
      return;
    }

    setState(() {
      _sourceImage = file;
      _recipe = null;
    });
  }

  Future<void> _generatePoster() async {
    final PetProfile? profile = context.read<PetProfileProvider>().profile;
    if (_sourceImage == null || profile == null) {
      _showMessage(context.tr('Choose a pet photo first.'));
      return;
    }

    final bool hasConsent = await _consentService.ensureConsent(context);
    if (!hasConsent || !mounted) return;

    setState(() {
      _isGenerating = true;
      _generatedImageBytes = null;
    });

    try {
      final String base64Image = await DoubaoAiService.imageToBase64(
        _sourceImage!,
      );
      final String prompt = _buildImagePrompt(
        _keywordsController.text,
        profile,
      );

      final Uint8List bytes = await _aiService.generateImage(
        prompt: prompt,
        size: '2K',
        referenceImageBase64: base64Image,
        watermark: false,
      );

      if (!mounted) return;
      setState(() {
        _generatedImageBytes = bytes;
        _recipe = _buildRecipe(_keywordsController.text, profile.name);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.tr('Generation failed. Please try again.'));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _savePoster({required bool addToAlbum}) async {
    final PetProfileProvider provider = context.read<PetProfileProvider>();
    final PetProfile? profile = provider.profile;
    if (_recipe == null || profile == null || _generatedImageBytes == null) {
      _showMessage(context.tr('Generate a poster before saving.'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String relativePath = await _imageService.saveBytes(
        _generatedImageBytes!,
        'ai_time_assets',
        profile.petId,
      );

      final PetMediaAsset asset = PetMediaAsset(
        assetId: 'studio_${DateTime.now().millisecondsSinceEpoch}',
        relativePath: relativePath,
        source: 'ai_time',
        title: _recipe!.title,
        keywords: _keywordsController.text.trim(),
        createdAt: DateTime.now(),
      );

      await provider.addStudioAsset(asset);
      if (addToAlbum) {
        await provider.addAlbumAsset(
          asset.copyWith(
            assetId: 'album_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        addToAlbum
            ? context.tr('Saved and added to album.')
            : context.tr('Material saved.'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _buildImagePrompt(String keywords, PetProfile profile) {
    final String name = profile.name;
    final String species = profile.species.toLowerCase();
    final String breed = profile.breed;
    final String styleHint = keywords.trim().isEmpty
        ? 'cute, warm, artistic poster style'
        : keywords.trim();

    return 'Create a beautiful artistic poster featuring a $breed $species named $name. '
        'Style: $styleHint. '
        'The poster should have a warm, dreamy aesthetic with soft lighting, '
        'vibrant colors, and a cohesive artistic theme. '
        'Include subtle decorative elements matching the theme. '
        'High quality, detailed, professional pet portrait illustration.';
  }

  _PosterRecipe _buildRecipe(String keywords, String petName) {
    final String normalized = keywords.trim().toLowerCase();
    final List<String> tokens = normalized
        .split(RegExp(r'[\s,]+'))
        .where((String item) => item.isNotEmpty)
        .toList();

    if (tokens.any(
      (String item) => item.contains('beach') || item.contains('summer'),
    )) {
      return _PosterRecipe(
        title: '$petName Summer Club',
        subtitle: 'Sunlight, sea breeze, and a very photogenic best friend.',
        keywords: tokens.isEmpty
            ? <String>['summer', 'coast', 'playful']
            : tokens.take(3).toList(),
        colors: const <Color>[
          Color(0xFFFFB703),
          Color(0xFFFF6B6B),
          Color(0xFF219EBC),
        ],
        icon: Icons.wb_sunny_rounded,
      );
    }

    if (tokens.any(
      (String item) => item.contains('space') || item.contains('galaxy'),
    )) {
      return _PosterRecipe(
        title: '$petName Cosmic Drift',
        subtitle: 'A dreamy orbit of sparkles, nebula haze, and zoomies.',
        keywords: tokens.isEmpty
            ? <String>['galaxy', 'glow', 'orbit']
            : tokens.take(3).toList(),
        colors: const <Color>[
          Color(0xFF3A0CA3),
          Color(0xFF7209B7),
          Color(0xFF4CC9F0),
        ],
        icon: Icons.auto_awesome,
      );
    }

    if (tokens.any(
      (String item) => item.contains('forest') || item.contains('nature'),
    )) {
      return _PosterRecipe(
        title: '$petName Wild Walk',
        subtitle: 'Soft trails, leafy air, and a calm little explorer.',
        keywords: tokens.isEmpty
            ? <String>['forest', 'calm', 'fresh']
            : tokens.take(3).toList(),
        colors: const <Color>[
          Color(0xFF588157),
          Color(0xFFA3B18A),
          Color(0xFFDAD7CD),
        ],
        icon: Icons.park_rounded,
      );
    }

    return _PosterRecipe(
      title: '$petName Moodboard',
      subtitle:
          'A keyword-driven keepsake built from your favorite pet moment.',
      keywords: tokens.isEmpty
          ? <String>['cute', 'daily', 'signature']
          : tokens.take(3).toList(),
      colors: const <Color>[
        AppColors.primary,
        AppColors.secondary,
        AppColors.accent,
      ],
      icon: Icons.photo_filter_rounded,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PetProfile? profile = context.watch<PetProfileProvider>().profile;
    final List<PetMediaAsset> studioAssets =
        profile?.studioAssets.toList() ?? <PetMediaAsset>[];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('AI Time'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFFFF4E2), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Turn a pet photo into a themed poster'),
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Use short keywords like "summer beach", "space cat", or "forest picnic".',
                    ),
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: VoiceTextField(
                          controller: _keywordsController,
                          decoration: InputDecoration(
                            labelText: context.tr('Keywords'),
                            hintText: context.tr(
                              'summer beach / cozy cafe / cosmic',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isGenerating ? null : _generatePoster,
                        child: _isGenerating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.tr('Generate')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPhoto(ImageSourceType.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(context.tr('Camera')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickPhoto(ImageSourceType.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(context.tr('Gallery')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 0.82,
              child: _PosterPreview(
                recipe: _recipe,
                sourceImage: _sourceImage,
                generatedImageBytes: _generatedImageBytes,
                isGenerating: _isGenerating,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _savePoster(addToAlbum: false),
                    icon: const Icon(Icons.save_alt),
                    label: Text(
                      _isSaving
                          ? context.tr('Saving...')
                          : context.tr('Save Material'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _savePoster(addToAlbum: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    icon: const Icon(Icons.collections_bookmark_outlined),
                    label: Text(context.tr('Save to Album')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(context.tr('Saved Materials'), style: AppTextStyles.title),
            const SizedBox(height: 12),
            if (studioAssets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.tr('Your generated posters will appear here.'),
                  style: AppTextStyles.caption,
                ),
              )
            else
              SizedBox(
                height: 138,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: studioAssets.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (BuildContext context, int index) {
                    final PetMediaAsset asset = studioAssets[index];
                    return _StudioAssetCard(asset: asset);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PosterPreview extends StatelessWidget {
  final _PosterRecipe? recipe;
  final File? sourceImage;
  final Uint8List? generatedImageBytes;
  final bool isGenerating;

  const _PosterPreview({
    required this.recipe,
    required this.sourceImage,
    this.generatedImageBytes,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    if (sourceImage == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr(
                'Pick a pet photo and generate a poster to preview it here.',
              ),
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (isGenerating) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.tr('Generating poster...')),
            ],
          ),
        ),
      );
    }

    if (generatedImageBytes != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Image.memory(
            generatedImageBytes!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }

    // Fallback: show local styled preview before AI generation
    if (recipe == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_filter_rounded,
                size: 48,
                color: AppColors.primary.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('Tap Generate to create AI poster'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: recipe!.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: recipe!.colors.last.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -12,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(
                recipe!.icon,
                size: 116,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 56,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: recipe!.keywords
                      .map(
                        (String tag) => Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: AppTextStyles.label.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Spacer(),
                Center(
                  child: Transform.rotate(
                    angle: -0.08,
                    child: Container(
                      width: 220,
                      height: 260,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.file(sourceImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  recipe!.title,
                  style: AppTextStyles.headline.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  recipe!.subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioAssetCard extends StatelessWidget {
  final PetMediaAsset asset;

  const _StudioAssetCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: FutureBuilder<File?>(
                future: ImageService().loadImage(asset.relativePath),
                builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
                  final File? file = snapshot.data;
                  if (file == null) {
                    return Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Center(
                        child: Icon(Icons.photo_filter_rounded),
                      ),
                    );
                  }

                  return Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              asset.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterRecipe {
  final String title;
  final String subtitle;
  final List<String> keywords;
  final List<Color> colors;
  final IconData icon;

  const _PosterRecipe({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.colors,
    required this.icon,
  });
}

enum ImageSourceType { camera, gallery }
