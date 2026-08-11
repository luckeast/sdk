import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import '../utils/debug_logger.dart';

/// Repository interface for user account operations.
abstract class UserAccountRepository {
  Future<UserAccount?> getCurrentUser();
  Future<void> saveUser(UserAccount user);
  Future<void> clearLoginState();
  Future<void> clearUser();
  Future<bool> isLoggedIn();
  Future<void> setLoggedIn(bool value);
}

/// Secure storage implementation of UserAccountRepository.
class SecureStorageUserRepository implements UserAccountRepository {
  static const String _userKey = 'vymra_current_user';
  static const String _loginKey = 'vymra_is_logged_in';
  static const String _userIdKey = 'vymra_user_id';
  static const String _nicknameKey = 'vymra_nickname';
  static const String _avatarPathKey = 'vymra_avatar_path';
  static const String _loginTokenKey = 'vymra_login_token';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  Future<UserAccount?> getCurrentUser() async {
    debugPrint('[LOGIN] getCurrentUser() start');
    final jsonString = await _secureStorage.read(key: _userKey);
    debugPrint('[LOGIN] secureStorage _userKey read result: ${jsonString != null ? "EXISTS" : "null"}');
    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final user = UserAccount.fromJson(json);
        debugPrint('[LOGIN] Parsed user from _userKey: userId=${user.userId}');
        return user;
      } catch (e) {
        DebugLogger.log(
          hypothesisId: 'D',
          location: 'user_account_repository.dart:31',
          message: 'Failed to parse secure storage user JSON',
          data: {'error': e.toString()},
        );
      }
    }

    final String secureUserId =
        await _secureStorage.read(key: _userIdKey) ?? '';
    debugPrint('[LOGIN] secureStorage _userIdKey read result: "$secureUserId"');
    if (secureUserId.trim().isNotEmpty) {
      final UserAccount fallbackUser = UserAccount(
        userId: secureUserId.trim(),
        username:
            (await _secureStorage.read(key: _nicknameKey))?.trim().isNotEmpty ==
                true
            ? (await _secureStorage.read(key: _nicknameKey))!.trim()
            : 'Pet Parent',
        loginToken: await _secureStorage.read(key: _loginTokenKey) ?? '',
        isLoggedIn: true,
        createdAt: DateTime.now(),
        lastLoginAt: null,
        freeAiUses: 0,
        avatarPath: await _secureStorage.read(key: _avatarPathKey) ?? '',
      );

      await _secureStorage.write(
        key: _userKey,
        value: jsonEncode(fallbackUser.toJson()),
      );
      debugPrint('[LOGIN] Recovered user from _userIdKey: ${fallbackUser.userId}');
      return fallbackUser;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userId = prefs.getString(_userIdKey)?.trim() ?? '';
    debugPrint('[LOGIN] prefs _userIdKey read result: "$userId"');
    if (userId.isEmpty) {
      debugPrint('[LOGIN] No user found in any storage');
      return null;
    }

    final UserAccount fallbackUser = UserAccount(
      userId: userId,
      username: (prefs.getString(_nicknameKey)?.trim().isNotEmpty ?? false)
          ? prefs.getString(_nicknameKey)!.trim()
          : 'Pet Parent',
      loginToken: prefs.getString(_loginTokenKey) ?? '',
      isLoggedIn: prefs.getBool(_loginKey) ?? true,
      createdAt: DateTime.now(),
      lastLoginAt: null,
      freeAiUses: 0,
      avatarPath: '',
    );

    // Repair the primary secure-storage copy so subsequent reads stay consistent.
    await _secureStorage.write(
      key: _userKey,
      value: jsonEncode(fallbackUser.toJson()),
    );
    debugPrint('[LOGIN] Recovered user from prefs _userIdKey: ${fallbackUser.userId}');
    return fallbackUser;
  }

  @override
  Future<void> saveUser(UserAccount user) async {
    // #region debug-point C:repository-save-start
    DebugLogger.log(
      hypothesisId: 'C',
      location: 'user_account_repository.dart:33',
      message: 'SecureStorageUserRepository.saveUser() started',
      data: {'userId': user.userId},
    );
    // #endregion

    try {
      final jsonString = jsonEncode(user.toJson());

      // #region debug-point C:before-secure-storage-write
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'user_account_repository.dart:44',
        message: 'Before secureStorage.write()',
        data: {'jsonLength': jsonString.length},
      );
      // #endregion

      await _secureStorage.write(key: _userKey, value: jsonString);
      await _secureStorage.write(key: _userIdKey, value: user.userId);
      await _secureStorage.write(key: _nicknameKey, value: user.username);
      await _secureStorage.write(key: _avatarPathKey, value: user.avatarPath);
      await _secureStorage.write(key: _loginTokenKey, value: user.loginToken);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.userId);
      await prefs.setString(_nicknameKey, user.username);
      await prefs.setString(_loginTokenKey, user.loginToken);

      // #region debug-point C:after-secure-storage-write
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'user_account_repository.dart:53',
        message: 'After secureStorage.write() success',
        data: {},
      );
      // #endregion
    } catch (e, stackTrace) {
      // #region debug-point D:save-user-exception
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'user_account_repository.dart:61',
        message: 'saveUser() exception caught',
        data: {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
      // #endregion
      rethrow;
    }
  }

  @override
  Future<void> clearUser() async {
    debugPrint('[DELETE_ACCOUNT] SecureStorageUserRepository.clearUser() start');
    await _secureStorage.delete(key: _userKey);
    debugPrint('[DELETE_ACCOUNT] Deleted secureStorage _userKey');
    await _secureStorage.delete(key: _userIdKey);
    debugPrint('[DELETE_ACCOUNT] Deleted secureStorage _userIdKey');
    await _secureStorage.delete(key: _nicknameKey);
    debugPrint('[DELETE_ACCOUNT] Deleted secureStorage _nicknameKey');
    await _secureStorage.delete(key: _avatarPathKey);
    debugPrint('[DELETE_ACCOUNT] Deleted secureStorage _avatarPathKey');
    await _secureStorage.delete(key: _loginTokenKey);
    debugPrint('[DELETE_ACCOUNT] Deleted secureStorage _loginTokenKey');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginKey);
    debugPrint('[DELETE_ACCOUNT] Deleted prefs _loginKey');
    await prefs.remove(_userIdKey);
    debugPrint('[DELETE_ACCOUNT] Deleted prefs _userIdKey');
    await prefs.remove(_nicknameKey);
    debugPrint('[DELETE_ACCOUNT] Deleted prefs _nicknameKey');
    await prefs.remove(_loginTokenKey);
    debugPrint('[DELETE_ACCOUNT] Deleted prefs _loginTokenKey');
    debugPrint('[DELETE_ACCOUNT] SecureStorageUserRepository.clearUser() completed');
  }

  @override
  Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginKey, false);
  }

  @override
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginKey) ?? false;
  }

  @override
  Future<void> setLoggedIn(bool value) async {
    // #region debug-point C:set-logged-in-start
    DebugLogger.log(
      hypothesisId: 'C',
      location: 'user_account_repository.dart:73',
      message: 'setLoggedIn() started',
      data: {'value': value},
    );
    // #endregion

    try {
      final prefs = await SharedPreferences.getInstance();

      // #region debug-point C:before-prefs-set
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'user_account_repository.dart:84',
        message: 'Before prefs.setBool()',
        data: {},
      );
      // #endregion

      await prefs.setBool(_loginKey, value);

      // #region debug-point C:after-prefs-set
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'user_account_repository.dart:93',
        message: 'After prefs.setBool() success',
        data: {},
      );
      // #endregion
    } catch (e, stackTrace) {
      // #region debug-point D:set-logged-in-exception
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'user_account_repository.dart:101',
        message: 'setLoggedIn() exception caught',
        data: {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
      // #endregion
      rethrow;
    }
  }
}
