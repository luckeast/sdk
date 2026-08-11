import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/meal_analysis.dart';
import '../models/pet_media_asset.dart';
import '../models/pet_profile.dart';
import '../providers/meal_analysis_provider.dart';
import '../providers/pet_profile_provider.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/voice_text_field.dart';
import 'pet_album_screen.dart';

/// Pet profile details with album carousel, import actions, and editable profile fields.
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final ImageService _imageService = ImageService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();

  String _species = 'Dog';
  String _gender = 'Male';
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  File? _avatarPreviewFile;
  bool _isSaving = false;
  bool _didBootstrap = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final PetProfileProvider petProvider = context.read<PetProfileProvider>();
      if (!petProvider.hasProfile) {
        await petProvider.loadDefaultProfile();
      }

      final PetProfile? profile = petProvider.profile;
      if (!mounted || profile == null) {
        return;
      }

      await context.read<MealAnalysisProvider>().loadAnalyses(profile.petId);
      await _bootstrapProfile(profile);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final PetProfile? profile = context.watch<PetProfileProvider>().profile;
    if (profile != null && !_didBootstrap) {
      _bootstrapProfile(profile);
    }
  }

  Future<void> _bootstrapProfile(PetProfile profile) async {
    _didBootstrap = true;
    _nameController.text = profile.name;
    _breedController.text = profile.breed;
    _weightController.text = profile.currentWeight.toString();
    _targetWeightController.text = profile.targetWeight.toString();
    _species = profile.species;
    _gender = profile.gender;
    _birthDate = profile.birthDate;

    final File? avatarFile = await _imageService.loadImage(profile.avatarPath);
    if (!mounted) {
      return;
    }

    setState(() {
      _avatarPreviewFile = avatarFile;
    });
  }

  Future<void> _pickAvatar() async {
    final File? file = await _showAvatarSourceSheet();
    if (file == null) {
      return;
    }

    setState(() {
      _avatarPreviewFile = file;
    });
  }

  Future<File?> _showAvatarSourceSheet() async {
    return showModalBottomSheet<File?>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: Text(context.tr('Take a photo')),
                  onTap: () async {
                    final File? file = await _imageService.captureImage();
                    if (context.mounted) {
                      Navigator.pop(context, file);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(context.tr('Choose from gallery')),
                  onTap: () async {
                    final File? file = await _imageService.pickFromGallery();
                    if (context.mounted) {
                      Navigator.pop(context, file);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    final String breed = _breedController.text.trim();
    final double weight = double.tryParse(_weightController.text) ?? 0;
    final double targetWeight =
        double.tryParse(_targetWeightController.text) ?? weight;

    if (name.isEmpty || breed.isEmpty || weight <= 0) {
      _showMessage(context.tr('Please fill in all required profile details.'));
      return;
    }

    final PetProfileProvider provider = context.read<PetProfileProvider>();
    final PetProfile? existing = provider.profile;
    if (existing == null) {
      _showMessage(context.tr('Create a pet profile first.'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      String avatarPath = existing.avatarPath;
      if (_avatarPreviewFile != null) {
        avatarPath = await _imageService.saveImage(
          _avatarPreviewFile!,
          'pet_images',
          existing.petId,
        );
      }

      final PetProfile updatedProfile = existing.copyWith(
        name: name,
        species: _species,
        breed: breed,
        birthDate: _birthDate,
        currentWeight: weight,
        targetWeight: targetWeight,
        avatarPath: avatarPath,
        gender: _gender,
        updatedAt: DateTime.now(),
      );

      await provider.saveProfile(updatedProfile);
      if (!mounted) {
        return;
      }

      final File? avatarFile = await _imageService.loadImage(
        updatedProfile.avatarPath,
      );
      if (mounted) {
        setState(() {
          _avatarPreviewFile = avatarFile;
        });
      }

      _showMessage(context.tr('Pet profile updated.'));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _addAlbumFromCamera() async {
    final File? file = await _imageService.captureImage();
    if (file == null) {
      return;
    }

    await _saveAlbumFile(
      file,
      source: 'camera',
      title: context.tr('Captured moment'),
    );
  }

  Future<void> _addAlbumFromGallery() async {
    final File? file = await _imageService.pickFromGallery();
    if (file == null) {
      return;
    }

    await _saveAlbumFile(
      file,
      source: 'gallery',
      title: context.tr('Imported memory'),
    );
  }

  Future<void> _saveAlbumFile(
    File file, {
    required String source,
    required String title,
  }) async {
    final PetProfileProvider provider = context.read<PetProfileProvider>();
    final PetProfile? profile = provider.profile;
    if (profile == null) {
      return;
    }

    final String relativePath = await _imageService.saveImage(
      file,
      'pet_album',
      profile.petId,
    );

    final PetMediaAsset asset = PetMediaAsset(
      assetId: 'album_${DateTime.now().millisecondsSinceEpoch}',
      relativePath: relativePath,
      source: source,
      title: title,
      createdAt: DateTime.now(),
    );

    await provider.addAlbumAsset(asset);
    _showMessage(context.tr('Added to pet album.'));
  }

  Future<void> _importFromAiScan() async {
    final List<MealAnalysis> analyses = context
        .read<MealAnalysisProvider>()
        .analyses;
    if (analyses.isEmpty) {
      _showMessage(context.tr('No AI Scan results available yet.'));
      return;
    }

    final MealAnalysis? selected = await showModalBottomSheet<MealAnalysis>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: analyses.length,
            itemBuilder: (BuildContext context, int index) {
              final MealAnalysis analysis = analyses[index];
              return ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(analysis.foodType),
                subtitle: Text(
                  DateFormat('MMM d · HH:mm').format(analysis.analyzedAt),
                ),
                onTap: () => Navigator.pop(context, analysis),
              );
            },
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final PetProfile? profile = context.read<PetProfileProvider>().profile;
    if (profile == null) {
      return;
    }

    final PetProfileProvider petProvider = context.read<PetProfileProvider>();
    final String? copiedPath = await _imageService.duplicateStoredImage(
      selected.photoPath,
      'pet_album',
      profile.petId,
    );
    if (copiedPath == null) {
      _showMessage(context.tr('Could not import that AI Scan photo.'));
      return;
    }

    await petProvider.addAlbumAsset(
      PetMediaAsset(
        assetId: 'album_${DateTime.now().millisecondsSinceEpoch}',
        relativePath: copiedPath,
        source: 'ai_scan',
        title: context.tr(
          'AI Scan · {foodType}',
          params: <String, String>{'foodType': context.tr(selected.foodType)},
        ),
        createdAt: DateTime.now(),
      ),
    );

    _showMessage(context.tr('AI Scan photo added to album.'));
  }

  Future<void> _importFromAiTime() async {
    final List<PetMediaAsset> studioAssets =
        context.read<PetProfileProvider>().profile?.studioAssets ??
        <PetMediaAsset>[];
    if (studioAssets.isEmpty) {
      _showMessage(context.tr('No AI Time materials saved yet.'));
      return;
    }

    final PetMediaAsset? selected = await showModalBottomSheet<PetMediaAsset>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: studioAssets.length,
            itemBuilder: (BuildContext context, int index) {
              final PetMediaAsset asset = studioAssets[index];
              return ListTile(
                leading: const Icon(Icons.photo_filter_rounded),
                title: Text(asset.title),
                subtitle: Text(
                  asset.keywords.isEmpty
                      ? context.tr('Saved material')
                      : asset.keywords,
                ),
                onTap: () => Navigator.pop(context, asset),
              );
            },
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    await context.read<PetProfileProvider>().addAlbumAsset(
      selected.copyWith(
        assetId: 'album_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      ),
    );

    _showMessage(context.tr('AI Time material added to album.'));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PetProfile? profile = context.watch<PetProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Pet Profile')),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isSaving ? context.tr('Saving...') : context.tr('Save'),
              style: AppTextStyles.body.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: profile == null
          ? Center(
              child: Text(
                context.tr('Create a pet profile to unlock this space.'),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.albumEntries.isNotEmpty) ...[
                    _AlbumHeroCarousel(
                      entries: profile.albumEntries,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PetAlbumScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                  ],
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _AnimatedProfileAvatar(
                          file: _avatarPreviewFile,
                          onTap: _isSaving ? null : _pickAvatar,
                        ),
                        const SizedBox(width: 18),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(profile.name, style: AppTextStyles.headline),
                              const SizedBox(height: 6),
                              Text(
                                '${context.tr(profile.species)} · ${profile.breed}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _AlbumImportRow(
                    onCamera: _addAlbumFromCamera,
                    onGallery: _addAlbumFromGallery,
                    onAiScan: _importFromAiScan,
                    onAiTime: _importFromAiTime,
                  ),
                  const SizedBox(height: 20),
                  _PetStats(profile: profile),
                  const SizedBox(height: 20),
                  AppCard(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: context.tr('Pet Name *'),
                          icon: Icons.pets,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _species,
                          decoration: InputDecoration(
                            labelText: context.tr('Species'),
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const <String>['Dog', 'Cat', 'Other']
                              .map(
                                (String species) => DropdownMenuItem<String>(
                                  value: species,
                                  child: Text(context.tr(species)),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? value) {
                                  if (value != null) {
                                    setState(() => _species = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _breedController,
                          label: context.tr('Breed *'),
                          icon: Icons.pets_outlined,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: InputDecoration(
                            labelText: context.tr('Gender'),
                            prefixIcon: Icon(Icons.wc),
                          ),
                          items: const <String>['Male', 'Female']
                              .map(
                                (String gender) => DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(context.tr(gender)),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (String? value) {
                                  if (value != null) {
                                    setState(() => _gender = value);
                                  }
                                },
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _isSaving ? null : _pickBirthDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: context.tr('Birth Date'),
                              prefixIcon: Icon(Icons.cake_outlined),
                            ),
                            child: Text(
                              DateFormat('yyyy/MM/dd').format(_birthDate),
                              style: AppTextStyles.body,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _weightController,
                          label: context.tr('Current Weight (kg) *'),
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _targetWeightController,
                          label: context.tr('Target Weight (kg)'),
                          icon: Icons.track_changes_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return VoiceTextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: keyboardType,
      enableSpeechInput: keyboardType == null,
      enabled: !_isSaving,
    );
  }
}

class _AlbumHeroCarousel extends StatefulWidget {
  final List<PetMediaAsset> entries;
  final VoidCallback onTap;

  const _AlbumHeroCarousel({required this.entries, required this.onTap});

  @override
  State<_AlbumHeroCarousel> createState() => _AlbumHeroCarouselState();
}

class _AlbumHeroCarouselState extends State<_AlbumHeroCarousel> {
  late final PageController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.72);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.entries.length < 2) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (!mounted || !_controller.hasClients) {
        return;
      }

      final double current = _controller.page ?? 0;
      final int nextIndex = (current.round() + 1) % widget.entries.length;
      _controller.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFF6EB), Color(0xFFF2FBF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            left: 22,
            child: Text(context.tr('Pet Gallery'), style: AppTextStyles.title),
          ),
          if (widget.entries.isEmpty)
            Positioned.fill(
              child: Center(
                child: Text(
                  context.tr('Add a few moments to bring the gallery to life.'),
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Positioned.fill(
              top: 54,
              child: GestureDetector(
                onTap: widget.onTap,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: widget.entries.length,
                  itemBuilder: (BuildContext context, int index) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? child) {
                        double page = index.toDouble();
                        if (_controller.position.hasContentDimensions) {
                          page =
                              _controller.page ??
                              _controller.initialPage.toDouble();
                        }

                        final double delta = (page - index).abs();
                        final double scale = 1 - (delta * 0.1).clamp(0.0, 0.1);
                        final double rotation = (page - index) * 0.16;
                        final double verticalLift =
                            18 * (1 - delta.clamp(0.0, 1.0));

                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(rotation)
                            ..translateByDouble(0, -verticalLift, 0, 1)
                            ..scaleByDouble(scale, scale, 1, 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _AlbumDeckCard(asset: widget.entries[index]),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedProfileAvatar extends StatefulWidget {
  final File? file;
  final VoidCallback? onTap;

  const _AnimatedProfileAvatar({required this.file, required this.onTap});

  @override
  State<_AnimatedProfileAvatar> createState() => _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<_AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double glow = 0.96 + (_controller.value * 0.05);
        return Transform.scale(
          scale: glow,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Hero(
                  tag: 'pet-avatar-hero',
                  child: Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.24),
                          blurRadius: 28 + (_controller.value * 8),
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(42),
                        child: widget.file == null
                            ? Container(
                                color: Colors.white.withOpacity(0.16),
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.white,
                                  size: 70,
                                ),
                              )
                            : Image.file(widget.file!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryDark,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumDeckCard extends StatelessWidget {
  final PetMediaAsset asset;

  const _AlbumDeckCard({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryDark.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: FutureBuilder<File?>(
                future: ImageService().loadImage(asset.relativePath),
                builder: (BuildContext context, AsyncSnapshot<File?> snapshot) {
                  final File? file = snapshot.data;
                  if (file == null) {
                    return Container(
                      color: AppColors.primary.withOpacity(0.12),
                      child: const Center(child: Icon(Icons.photo, size: 38)),
                    );
                  }

                  return Image.file(file, fit: BoxFit.cover);
                },
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.44),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.title,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d · HH:mm').format(asset.createdAt),
                  style: AppTextStyles.label.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumImportRow extends StatelessWidget {
  final Future<void> Function() onCamera;
  final Future<void> Function() onGallery;
  final Future<void> Function() onAiScan;
  final Future<void> Function() onAiTime;

  const _AlbumImportRow({
    required this.onCamera,
    required this.onGallery,
    required this.onAiScan,
    required this.onAiTime,
  });

  @override
  Widget build(BuildContext context) {
    final List<
      ({
        String title,
        IconData icon,
        Color color,
        Future<void> Function() onTap,
      })
    >
    actions =
        <
          ({
            String title,
            IconData icon,
            Color color,
            Future<void> Function() onTap,
          })
        >[
          (
            title: context.tr('Camera'),
            icon: Icons.camera_alt_outlined,
            color: AppColors.primary,
            onTap: onCamera,
          ),
          (
            title: context.tr('Gallery'),
            icon: Icons.photo_library_outlined,
            color: AppColors.secondary,
            onTap: onGallery,
          ),
          (
            title: context.tr('AI Scan'),
            icon: Icons.auto_awesome_motion_outlined,
            color: AppColors.accent,
            onTap: onAiScan,
          ),
          (
            title: context.tr('AI Time'),
            icon: Icons.photo_filter_rounded,
            color: AppColors.error,
            onTap: onAiTime,
          ),
        ];

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final action = actions[index];
          return InkWell(
            onTap: action.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Ink(
              width: 120,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(action.icon, color: action.color),
                    Text(
                      action.title,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: action.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PetStats extends StatelessWidget {
  final PetProfile profile;

  const _PetStats({required this.profile});

  @override
  Widget build(BuildContext context) {
    final List<({String label, String value})> stats =
        <({String label, String value})>[
          (label: context.tr('Age'), value: _ageText(profile.birthDate)),
          (
            label: context.tr('Current'),
            value: '${profile.currentWeight.toStringAsFixed(1)} kg',
          ),
          (
            label: context.tr('Target'),
            value: '${profile.targetWeight.toStringAsFixed(1)} kg',
          ),
        ];

    return Row(
      children: stats
          .map(
            (item) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Text(
                      item.value,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(item.label, style: AppTextStyles.label),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _ageText(DateTime birthDate) {
    final int months = math.max(
      1,
      ((DateTime.now().difference(birthDate).inDays) / 30).round(),
    );
    if (months >= 12) {
      return '${(months / 12).toStringAsFixed(1)} yr';
    }

    return '$months mo';
  }
}
