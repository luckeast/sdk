import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling image capture and storage.
class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Capture an image using the camera.
  Future<File?> captureImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Pick an image from the photo gallery.
  Future<File?> pickFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Save an image to app documents directory and return relative path.
  Future<String> saveImage(File imageFile, String folder, String prefix) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${appDir.path}/$folder');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final fileName = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await imageFile.copy('${targetDir.path}/$fileName');
    debugPrint('Image saved: $folder/$fileName');
    return '$folder/$fileName';
  }

  /// Save raw bytes to app documents directory and return relative path.
  Future<String> saveBytes(
    Uint8List bytes,
    String folder,
    String prefix, {
    String extension = 'png',
  }) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory targetDir = Directory('${appDir.path}/$folder');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final String fileName =
        '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final File file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return '$folder/$fileName';
  }

  /// Load an image from relative path.
  Future<File?> loadImage(String relativePath) async {
    if (relativePath.isEmpty) return null;
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$relativePath');
    if (file.existsSync()) return file;
    return null;
  }

  /// Duplicate a previously stored image into another folder.
  Future<String?> duplicateStoredImage(
    String relativePath,
    String targetFolder,
    String prefix,
  ) async {
    final File? sourceFile = await loadImage(relativePath);
    if (sourceFile == null) {
      return null;
    }

    return saveImage(sourceFile, targetFolder, prefix);
  }

  /// Delete an image by relative path.
  Future<void> deleteImage(String relativePath) async {
    if (relativePath.isEmpty) return;
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$relativePath');
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
