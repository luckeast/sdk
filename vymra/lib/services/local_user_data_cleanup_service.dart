import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_logger.dart';

/// Clears user-owned local storage after account deletion.
class LocalUserDataCleanupService {
  static const List<String> _hiveBoxNames = <String>[
    'pet_profiles',
    'health_records',
    'meal_analyses',
    'growth_progress',
    'vaccine_reminders',
    'ai_chat_records',
    'purchase_records',
  ];

  static const List<String> _sharedPreferenceKeys = <String>[
    'selected_pet_profile_id',
    'vymra_pet_community_posts',
    'vymra_blocked_community_authors',
  ];

  static const List<String> _sharedPreferencePrefixes = <String>[
    'vymra_achievements_',
  ];

  static const List<String> _documentFolders = <String>[
    'pet_images',
    'user_avatars',
    'pet_album',
    'ai_time_assets',
    'meal_photos',
    'community_posts',
    'health_records',
  ];

  Future<void> clearUserData() async {
    await _clearHiveBoxes();
    await _clearSharedPreferences();
    await _clearDocumentsFolders();
  }

  void _log(String message, {Map<String, dynamic>? data}) {
    DebugLogger.log(
      hypothesisId: 'D',
      location: 'local_user_data_cleanup_service.dart',
      message: message,
      data: data,
    );
  }

  Future<void> _clearHiveBoxes() async {
    debugPrint('[DELETE_ACCOUNT] _clearHiveBoxes start. Boxes to clear: $_hiveBoxNames');
    final Directory appDir = await getApplicationDocumentsDirectory();
    debugPrint('[DELETE_ACCOUNT] Hive storage path: ${appDir.path}');

    // Close all open boxes first so repository singletons release their
    // cached Box references and will re-open fresh boxes on next access.
    try {
      debugPrint('[DELETE_ACCOUNT] Closing all Hive boxes...');
      await Hive.close();
      debugPrint('[DELETE_ACCOUNT] Hive.close() completed');
      _log('Closed all Hive boxes');
    } catch (e) {
      debugPrint('[DELETE_ACCOUNT] Hive.close() FAILED: $e');
      _log('Failed to close Hive boxes', data: {'error': e.toString()});
    }

    for (final String boxName in _hiveBoxNames) {
      bool hiveDeleteSuccess = false;
      try {
        final bool exists = await Hive.boxExists(boxName);
        debugPrint('[DELETE_ACCOUNT] Box "$boxName" boxExists=$exists');

        if (exists) {
          debugPrint('[DELETE_ACCOUNT] Deleting box "$boxName" via Hive.deleteBoxFromDisk()...');
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('[DELETE_ACCOUNT] Hive.deleteBoxFromDisk() completed for "$boxName"');
          _log('Deleted Hive box from disk', data: {'boxName': boxName});
        }
        hiveDeleteSuccess = true;
      } catch (e) {
        _log('Failed to delete Hive box', data: {'boxName': boxName, 'error': e.toString()});
        debugPrint('[DELETE_ACCOUNT] FAILED to delete box "$boxName" via Hive API: $e');
      }

      // Fallback to filesystem deletion to ensure physical files are removed
      final List<String> fileNames = <String>[
        '$boxName.hive',
        '$boxName.lock',
        '$boxName.hivec',
      ];
      for (final String fileName in fileNames) {
        final File file = File('${appDir.path}/$fileName');
        if (file.existsSync()) {
          debugPrint('[DELETE_ACCOUNT] Fallback deleting file: ${file.path}');
          try {
            await file.delete();
            debugPrint('[DELETE_ACCOUNT] Fallback deleted: ${file.path}');
          } catch (e) {
            debugPrint('[DELETE_ACCOUNT] Fallback delete FAILED: ${file.path}, error: $e');
          }
        }
      }

      try {
        final bool stillExists = await Hive.boxExists(boxName);
        debugPrint('[DELETE_ACCOUNT] Box "$boxName" Hive.boxExists after cleanup: $stillExists, hiveDeleteSuccess=$hiveDeleteSuccess');
      } catch (e) {
        debugPrint('[DELETE_ACCOUNT] Failed to check boxExists for "$boxName": $e');
      }
    }
    debugPrint('[DELETE_ACCOUNT] _clearHiveBoxes completed');
  }

  Future<void> _clearSharedPreferences() async {
    try {
      final SharedPreferences preferences = await SharedPreferences.getInstance();

      for (final String key in _sharedPreferenceKeys) {
        await preferences.remove(key);
      }

      final Set<String> keysToRemove = preferences
          .getKeys()
          .where(
            (String key) => _sharedPreferencePrefixes.any(
              (String prefix) => key.startsWith(prefix),
            ),
          )
          .toSet();

      for (final String key in keysToRemove) {
        await preferences.remove(key);
      }

      _log('Cleared SharedPreferences keys', data: {
        'explicitKeys': _sharedPreferenceKeys,
        'prefixKeysRemoved': keysToRemove.toList(),
      });
    } catch (e) {
      _log('Failed to clear SharedPreferences', data: {'error': e.toString()});
    }
  }

  Future<void> _clearDocumentsFolders() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();

      for (final String folderName in _documentFolders) {
        try {
          final Directory directory = Directory('${appDir.path}/$folderName');
          if (directory.existsSync()) {
            await directory.delete(recursive: true);
            _log('Deleted documents folder', data: {'folderName': folderName});
          }
        } catch (e) {
          _log('Failed to delete documents folder', data: {'folderName': folderName, 'error': e.toString()});
        }
      }
    } catch (e) {
      _log('Failed to clear documents folders', data: {'error': e.toString()});
    }
  }
}
