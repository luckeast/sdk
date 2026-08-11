import 'package:flutter/foundation.dart';

import '../models/user_account.dart';
import '../repositories/user_account_repository.dart';
import '../repositories/purchase_record_repository.dart';
import '../utils/debug_logger.dart';
import 'api_manager.dart';
import 'local_user_data_cleanup_service.dart';

/// Service for handling user authentication.
class AuthService {
  final UserAccountRepository _repository;
  final PurchaseRecordRepository? _purchaseRepository;
  final ApiManager _apiManager;
  final LocalUserDataCleanupService _localUserDataCleanupService;
  static const String _defaultUsername = 'Pet Parent';

  AuthService(
    this._repository, {
    PurchaseRecordRepository? purchaseRepository,
    ApiManager? apiManager,
    LocalUserDataCleanupService? localUserDataCleanupService,
  }) : _purchaseRepository = purchaseRepository,
       _apiManager = apiManager ?? ApiManager(),
       _localUserDataCleanupService =
           localUserDataCleanupService ?? LocalUserDataCleanupService();

  /// Authenticate user with the backend login endpoint.
  Future<UserAccount?> login([String? username]) async {
    // #region debug-point B:service-login-start
    DebugLogger.log(
      hypothesisId: 'B',
      location: 'auth_service.dart:12',
      message: 'AuthService.login() started',
      data: {'username': username},
    );
    // #endregion

    try {
      final UserAccount? existingUser = await _repository.getCurrentUser();
      debugPrint('[LOGIN] AuthService.login() existingUser: ${existingUser?.userId ?? "null"}');
      if (existingUser != null) {
        debugPrint('[LOGIN] Restoring existing user: ${existingUser.userId}');
        final UserAccount restoredUser = existingUser.copyWith(
          isLoggedIn: true,
          lastLoginAt: DateTime.now(),
        );
        await _repository.saveUser(restoredUser);
        await _repository.setLoggedIn(true);
        return restoredUser;
      }

      final ApiResponse response = await _apiManager.postJson(
        _apiManager.buildApiUri(path: 'auth/login'),
        body: <String, dynamic>{
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
        },
      );
      final Map<String, dynamic> payload = response.jsonMap();
      final dynamic rawData = payload['data'];
      final Map<String, dynamic> data = rawData is Map<String, dynamic>
          ? rawData
          : <String, dynamic>{};
      final String userId = data['user_id']?.toString().trim() ?? '';
      final String nickname =
          (data['nickname'] as String?)?.trim().isNotEmpty == true
          ? (data['nickname'] as String).trim()
          : _defaultUsername;
      if (userId.isEmpty) {
        throw const ApiException('Login response is missing data.user_id');
      }

      final user = UserAccount(
        userId: userId,
        username: nickname,
        loginToken:
            (data['token'] as String?) ?? (payload['token'] as String?) ?? '',
        isLoggedIn: true,
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        freeAiUses: existingUser?.freeAiUses ?? 0,
        avatarPath: existingUser?.avatarPath ?? '',
      );

      // #region debug-point C:before-save-user
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'auth_service.dart:39',
        message: 'Before repository.saveUser()',
        data: {'user': user.toJson()},
      );
      // #endregion

      await _repository.saveUser(user);

      // #region debug-point C:after-save-user
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'auth_service.dart:48',
        message: 'After repository.saveUser()',
        data: {},
      );
      // #endregion

      // #region debug-point C:before-set-logged-in
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'auth_service.dart:55',
        message: 'Before repository.setLoggedIn(true)',
        data: {},
      );
      // #endregion

      await _repository.setLoggedIn(true);

      // #region debug-point C:after-set-logged-in
      DebugLogger.log(
        hypothesisId: 'C',
        location: 'auth_service.dart:64',
        message: 'After repository.setLoggedIn(true)',
        data: {},
      );
      // #endregion

      // Grant 100 coins welcome bonus for new users
      final bool isNewUser =
          existingUser == null || existingUser.userId != user.userId;
      if (_purchaseRepository != null && isNewUser) {
        await _purchaseRepository.addCoins(100);
      }

      return user;
    } catch (e, stackTrace) {
      // #region debug-point D:service-exception
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'auth_service.dart:74',
        message: 'AuthService exception caught',
        data: {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
      // #endregion
      return null;
    }
  }

  /// Check if user is already logged in.
  Future<bool> checkAutoLogin() async {
    return await _repository.isLoggedIn();
  }

  /// Get current user.
  Future<UserAccount?> getCurrentUser() async {
    return await _repository.getCurrentUser();
  }

  /// Persist user profile changes.
  Future<void> updateUser(UserAccount user) async {
    await _repository.saveUser(user);
  }

  /// Logout current user.
  Future<void> logout() async {
    await _repository.clearLoginState();
  }

  /// Delete account and all data.
  Future<void> deleteAccount() async {
    debugPrint('[DELETE_ACCOUNT] AuthService.deleteAccount() start');
    final UserAccount? currentUser = await _repository.getCurrentUser();
    final String userId = currentUser?.userId.trim() ?? '';
    debugPrint('[DELETE_ACCOUNT] currentUser userId: "$userId"');

    if (userId.isNotEmpty) {
      try {
        debugPrint('[DELETE_ACCOUNT] Calling backend auth/deleteAccount...');
        await _apiManager.postJson(
          _apiManager.buildApiUri(path: 'auth/deleteAccount'),
          body: <String, dynamic>{'user_id': userId},
        );
        debugPrint('[DELETE_ACCOUNT] Backend auth/deleteAccount success');
      } catch (e) {
        debugPrint('[DELETE_ACCOUNT] Backend auth/deleteAccount FAILED: $e');
        DebugLogger.log(
          hypothesisId: 'D',
          location: 'auth_service.dart:deleteAccount',
          message: 'Backend deleteAccount call failed; proceeding with local cleanup',
          data: {'error': e.toString()},
        );
      }
    }

    try {
      debugPrint('[DELETE_ACCOUNT] Calling repository.clearUser()...');
      await _repository.clearUser();
      debugPrint('[DELETE_ACCOUNT] repository.clearUser() success');
    } catch (e) {
      debugPrint('[DELETE_ACCOUNT] repository.clearUser() FAILED: $e');
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'auth_service.dart:deleteAccount',
        message: 'clearUser failed; proceeding with local data cleanup',
        data: {'error': e.toString()},
      );
    }

    try {
      debugPrint('[DELETE_ACCOUNT] Calling localUserDataCleanupService.clearUserData()...');
      await _localUserDataCleanupService.clearUserData();
      debugPrint('[DELETE_ACCOUNT] localUserDataCleanupService.clearUserData() success');
    } catch (e, stackTrace) {
      debugPrint('[DELETE_ACCOUNT] localUserDataCleanupService.clearUserData() FAILED: $e');
      debugPrint('[DELETE_ACCOUNT] StackTrace: $stackTrace');
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'auth_service.dart:deleteAccount',
        message: 'clearUserData failed',
        data: {'error': e.toString()},
      );
      rethrow;
    }
    debugPrint('[DELETE_ACCOUNT] AuthService.deleteAccount() completed');
  }
}
