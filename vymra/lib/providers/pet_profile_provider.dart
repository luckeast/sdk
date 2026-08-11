import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/pet_media_asset.dart';
import '../models/pet_profile.dart';
import '../repositories/pet_profile_repository.dart';

/// Provider for managing pet profile state.
class PetProfileProvider extends ChangeNotifier {
  final PetProfileRepository _repository;
  PetProfile? _profile;
  List<PetProfile> _profiles = <PetProfile>[];
  bool _isLoading = false;
  String? _error;

  PetProfileProvider(this._repository);

  PetProfile? get profile => _profile;
  List<PetProfile> get profiles => List<PetProfile>.unmodifiable(_profiles);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasProfile => _profile != null;

  Future<void> loadProfile(String petId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.getProfile(petId);
      await _repository.setSelectedProfileId(_profile?.petId);
      await _refreshProfiles();
    } catch (e) {
      _error = AppStrings.tr('Failed to load pet profile');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDefaultProfile() async {
    debugPrint('[PET_PROVIDER] loadDefaultProfile() start');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profile = await _repository.getDefaultProfile();
      debugPrint('[PET_PROVIDER] getDefaultProfile returned: ${_profile?.name ?? "null"}');
      await _refreshProfiles();
      debugPrint('[PET_PROVIDER] _profiles count after refresh: ${_profiles.length}');
    } catch (e, stackTrace) {
      _profile = null;
      _profiles = <PetProfile>[];
      _error = AppStrings.tr('Failed to load pet profile');
      debugPrint('[PET_PROVIDER] loadDefaultProfile FAILED: $e');
      debugPrint('[PET_PROVIDER] StackTrace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear all in-memory profile state (used after account deletion).
  void reset() {
    debugPrint('[PET_PROVIDER] reset() called');
    _profile = null;
    _profiles = <PetProfile>[];
    _error = null;
    notifyListeners();
  }

  Future<void> saveProfile(PetProfile profile) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.saveProfile(profile);
      await _repository.setSelectedProfileId(profile.petId);
      _profile = profile;
      await _refreshProfiles();
      _error = null;
    } catch (e) {
      _error = AppStrings.tr('Failed to save pet profile');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createDefaultProfile({
    required String name,
    required String species,
    required String breed,
    required DateTime birthDate,
    required double weight,
    String gender = 'Male',
  }) async {
    final PetProfile profile = PetProfile(
      petId: 'pet_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      species: species,
      breed: breed,
      birthDate: birthDate,
      currentWeight: weight,
      targetWeight: weight,
      gender: gender,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await saveProfile(profile);
  }

  Future<void> switchProfile(String petId) async {
    if (_profile?.petId == petId) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _repository.getProfile(petId);
      await _repository.setSelectedProfileId(_profile?.petId);
      await _refreshProfiles();
      _error = null;
    } catch (e) {
      _error = AppStrings.tr('Failed to switch pet profile');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _refreshProfiles();
      _error = null;
    } catch (e) {
      _error = AppStrings.tr('Failed to load pet profiles');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAvatarPath(String avatarPath) async {
    final PetProfile? existing = _profile;
    if (existing == null) {
      return;
    }

    await saveProfile(
      existing.copyWith(avatarPath: avatarPath, updatedAt: DateTime.now()),
    );
  }

  Future<void> addAlbumAsset(PetMediaAsset asset) async {
    final PetProfile? existing = _profile;
    if (existing == null) {
      return;
    }

    final List<PetMediaAsset> updatedEntries = <PetMediaAsset>[
      asset,
      ...existing.albumEntries.where(
        (PetMediaAsset item) => item.assetId != asset.assetId,
      ),
    ];

    await saveProfile(
      existing.copyWith(
        albumEntries: updatedEntries,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> removeAlbumAsset(String assetId) async {
    final PetProfile? existing = _profile;
    if (existing == null) {
      return;
    }

    await saveProfile(
      existing.copyWith(
        albumEntries: existing.albumEntries
            .where((PetMediaAsset item) => item.assetId != assetId)
            .toList(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> addStudioAsset(PetMediaAsset asset) async {
    final PetProfile? existing = _profile;
    if (existing == null) {
      return;
    }

    final List<PetMediaAsset> updatedAssets = <PetMediaAsset>[
      asset,
      ...existing.studioAssets.where(
        (PetMediaAsset item) => item.assetId != asset.assetId,
      ),
    ];

    await saveProfile(
      existing.copyWith(studioAssets: updatedAssets, updatedAt: DateTime.now()),
    );
  }

  Future<void> _refreshProfiles() async {
    _profiles = await _repository.getAllProfiles();
    if (_profile == null && _profiles.isNotEmpty) {
      _profile = _profiles.first;
      await _repository.setSelectedProfileId(_profile!.petId);
      return;
    }

    final String? currentPetId = _profile?.petId;
    if (currentPetId == null) {
      return;
    }

    for (final PetProfile item in _profiles) {
      if (item.petId == currentPetId) {
        _profile = item;
        return;
      }
    }
  }
}
