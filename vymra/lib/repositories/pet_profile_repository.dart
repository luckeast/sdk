import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_profile.dart';

/// Repository interface for pet profile CRUD operations.
abstract class PetProfileRepository {
  Future<PetProfile?> getProfile(String petId);
  Future<PetProfile?> getDefaultProfile();
  Future<List<PetProfile>> getAllProfiles();
  Future<String?> getSelectedProfileId();
  Future<void> setSelectedProfileId(String? petId);
  Future<void> saveProfile(PetProfile profile);
  Future<void> deleteProfile(String petId);
  Future<String> saveImage(File imageFile, String petId);
  Future<void> deleteImage(String relativePath);
}

/// Hive implementation of PetProfileRepository.
class HivePetProfileRepository implements PetProfileRepository {
  static const String _boxName = 'pet_profiles';
  static const String _selectedProfileKey = 'selected_pet_profile_id';
  Box<PetProfile>? _box;

  Future<Box<PetProfile>> get _boxInstance async {
    debugPrint('[PET_REPO] _boxInstance called. _box isNull=${_box == null}, isOpen=${_box?.isOpen}');
    if (_box != null && !_box!.isOpen) {
      debugPrint('[PET_REPO] Box was closed, resetting _box');
      _box = null;
    }
    _box ??= await Hive.openBox<PetProfile>(_boxName);
    debugPrint('[PET_REPO] Box opened. Keys count: ${_box!.length}');
    return _box!;
  }

  @override
  Future<PetProfile?> getProfile(String petId) async {
    final box = await _boxInstance;
    return box.get(petId);
  }

  @override
  Future<PetProfile?> getDefaultProfile() async {
    debugPrint('[PET_REPO] getDefaultProfile() start');
    final box = await _boxInstance;
    debugPrint('[PET_REPO] box.isEmpty=${box.isEmpty}, box.length=${box.length}');
    if (box.isEmpty) {
      debugPrint('[PET_REPO] getDefaultProfile() returning null (box empty)');
      return null;
    }

    final String? selectedProfileId = await getSelectedProfileId();
    debugPrint('[PET_REPO] selectedProfileId=$selectedProfileId');
    if (selectedProfileId != null) {
      final PetProfile? selectedProfile = box.get(selectedProfileId);
      debugPrint('[PET_REPO] selectedProfile found=${selectedProfile != null}');
      if (selectedProfile != null) {
        return selectedProfile;
      }
    }

    debugPrint('[PET_REPO] returning first profile: ${box.values.first.name}');
    return box.values.first;
  }

  @override
  Future<List<PetProfile>> getAllProfiles() async {
    final box = await _boxInstance;
    return box.values.toList();
  }

  @override
  Future<String?> getSelectedProfileId() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getString(_selectedProfileKey);
  }

  @override
  Future<void> setSelectedProfileId(String? petId) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (petId == null || petId.isEmpty) {
      await preferences.remove(_selectedProfileKey);
      return;
    }
    await preferences.setString(_selectedProfileKey, petId);
  }

  @override
  Future<void> saveProfile(PetProfile profile) async {
    final box = await _boxInstance;
    await box.put(profile.petId, profile);
  }

  @override
  Future<void> deleteProfile(String petId) async {
    final box = await _boxInstance;
    final profile = box.get(petId);
    if (profile != null && profile.avatarPath.isNotEmpty) {
      await deleteImage(profile.avatarPath);
    }
    await box.delete(petId);

    final String? selectedProfileId = await getSelectedProfileId();
    if (selectedProfileId == petId) {
      final List<PetProfile> remainingProfiles = box.values.toList();
      await setSelectedProfileId(
        remainingProfiles.isEmpty ? null : remainingProfiles.first.petId,
      );
    }
  }

  @override
  Future<String> saveImage(File imageFile, String petId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/pet_images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final fileName =
        '${petId}_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await imageFile.copy('${imagesDir.path}/$fileName');
    return 'pet_images/$fileName';
  }

  @override
  Future<void> deleteImage(String relativePath) async {
    if (relativePath.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$relativePath');
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
