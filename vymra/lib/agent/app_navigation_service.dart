import 'package:flutter/material.dart';

/// Shared app navigation bridge so global services can switch tabs and push pages.
class AppNavigationService {
  AppNavigationService._();

  static final AppNavigationService instance = AppNavigationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  void Function(int index)? _tabSelector;

  BuildContext? get context => navigatorKey.currentContext;

  void registerTabSelector(void Function(int index) selector) {
    _tabSelector = selector;
  }

  void unregisterTabSelector() {
    _tabSelector = null;
  }

  void selectMainTab(int index) {
    _tabSelector?.call(index);
  }

  Future<T?> push<T>(Route<T> route) async {
    return navigatorKey.currentState?.push(route);
  }

  void popIfPossible<T extends Object?>([T? result]) {
    final NavigatorState? navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop<T>(result);
    }
  }
}
