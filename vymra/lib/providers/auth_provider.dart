import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../models/user_account.dart';
import '../services/auth_service.dart';
import '../utils/debug_logger.dart';

/// Provider for managing authentication state.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  UserAccount? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AuthProvider(
    this._authService, {
    UserAccount? initialUser,
    bool initialLoggedIn = false,
  }) : _user = initialUser,
       _isLoggedIn = initialLoggedIn;

  UserAccount? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  int get freeAiUses => _user?.freeAiUses ?? 0;

  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isLoggedIn = await _authService.checkAutoLogin();
      if (_isLoggedIn) {
        _user = await _authService.getCurrentUser();
      }
    } catch (e) {
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login([String? username]) async {
    // #region debug-point A:login-method-start
    DebugLogger.log(
      hypothesisId: 'A',
      location: 'auth_provider.dart:28',
      message: 'AuthProvider.login() started',
      data: {'username': username, 'currentIsLoading': _isLoading},
    );
    // #endregion

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // #region debug-point B:before-service-login
      DebugLogger.log(
        hypothesisId: 'B',
        location: 'auth_provider.dart:40',
        message: 'Before authService.login()',
        data: {'username': username},
      );
      // #endregion

      final user = await _authService.login(username);

      // #region debug-point B:after-service-login
      DebugLogger.log(
        hypothesisId: 'B',
        location: 'auth_provider.dart:49',
        message: 'After authService.login()',
        data: {'user': user?.toJson()},
      );
      // #endregion

      if (user != null) {
        _user = user;
        _isLoggedIn = true;
        _error = null;
        notifyListeners();

        // #region debug-point A:login-success
        DebugLogger.log(
          hypothesisId: 'A',
          location: 'auth_provider.dart:62',
          message: 'Login success - state updated',
          data: {'isLoggedIn': _isLoggedIn, 'userId': user.userId},
        );
        // #endregion

        return true;
      } else {
        _error = AppStrings.tr('Invalid username. Please try again.');
        notifyListeners();

        // #region debug-point A:login-null-user
        DebugLogger.log(
          hypothesisId: 'A',
          location: 'auth_provider.dart:75',
          message: 'Login failed - user is null',
          data: {},
        );
        // #endregion

        return false;
      }
    } catch (e, stackTrace) {
      // #region debug-point D:login-exception
      DebugLogger.log(
        hypothesisId: 'D',
        location: 'auth_provider.dart:85',
        message: 'Login exception caught',
        data: {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
      // #endregion

      _error = AppStrings.tr('Login failed. Please try again.');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();

      // #region debug-point A:login-finally
      DebugLogger.log(
        hypothesisId: 'A',
        location: 'auth_provider.dart:99',
        message: 'Login method finally block',
        data: {'isLoading': _isLoading, 'isLoggedIn': _isLoggedIn},
      );
      // #endregion
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _user = null;
      _isLoggedIn = false;
    } catch (e) {
      _error = AppStrings.tr('Logout failed');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      _user = await _authService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      _error = AppStrings.tr('Failed to refresh account data');
      notifyListeners();
    }
  }

  Future<void> updateUserProfile({
    required String username,
    required String avatarPath,
  }) async {
    final UserAccount? currentUser = _user;
    if (currentUser == null) {
      _error = AppStrings.tr('No active user');
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final UserAccount updatedUser = currentUser.copyWith(
        username: username.trim().isEmpty
            ? currentUser.username
            : username.trim(),
        avatarPath: avatarPath,
      );
      await _authService.updateUser(updatedUser);
      _user = updatedUser;
    } catch (e) {
      _error = AppStrings.tr('Failed to update profile');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> consumeFreeAiUse() async {
    final UserAccount? currentUser = _user;
    if (currentUser == null || currentUser.freeAiUses <= 0) {
      return false;
    }

    final UserAccount updatedUser = currentUser.copyWith(
      freeAiUses: currentUser.freeAiUses - 1,
    );
    await _authService.updateUser(updatedUser);
    _user = updatedUser;
    notifyListeners();
    return true;
  }

  Future<void> addFreeAiUses(int amount) async {
    final UserAccount? currentUser = _user;
    if (currentUser == null || amount <= 0) {
      return;
    }

    final UserAccount updatedUser = currentUser.copyWith(
      freeAiUses: currentUser.freeAiUses + amount,
    );
    await _authService.updateUser(updatedUser);
    _user = updatedUser;
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    debugPrint('[DELETE_ACCOUNT] AuthProvider.deleteAccount() start');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.deleteAccount();
      _user = null;
      _isLoggedIn = false;
      debugPrint('[DELETE_ACCOUNT] AuthProvider.deleteAccount() success');
      return true;
    } catch (e, stackTrace) {
      _error = AppStrings.tr('Failed to delete account');
      debugPrint('[DELETE_ACCOUNT] AuthProvider.deleteAccount() FAILED: $e');
      debugPrint('[DELETE_ACCOUNT] StackTrace: $stackTrace');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
