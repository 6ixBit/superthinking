import 'package:flutter/widgets.dart';

class AppLifecycleService with WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  static bool isInForeground = true;
  static bool _initialized = false;

  AppLifecycleService._internal();

  static void initialize() {
    if (_initialized) return;
    WidgetsBinding.instance.addObserver(_instance);
    // Initialize with current state if available
    final state = WidgetsBinding.instance.lifecycleState;
    isInForeground = state == null || state == AppLifecycleState.resumed;
    _initialized = true;
  }

  static void dispose() {
    if (!_initialized) return;
    WidgetsBinding.instance.removeObserver(_instance);
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isInForeground = state == AppLifecycleState.resumed;
  }
}
