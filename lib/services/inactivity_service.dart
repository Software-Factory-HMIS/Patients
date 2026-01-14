import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import '../screens/splash_screen.dart';

class InactivityService {
  static const Duration _inactivityTimeout = Duration(hours: 1);
  static InactivityService? _instance;
  static InactivityService get instance => _instance ??= InactivityService._();

  InactivityService._();

  DateTime? _lastActivityTime;
  Timer? _inactivityTimer;
  bool _isInitialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Set the navigator key for navigation after logout
  void setNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  /// Initialize the inactivity service
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;
    // Only start timer if user is logged in
    if (AuthService.instance.isLoggedIn) {
      _resetActivity();
    }
  }

  /// Reset the activity timer (call this on user interaction)
  void resetActivity() {
    // Only reset if user is logged in
    if (AuthService.instance.isLoggedIn) {
      _resetActivity();
    }
  }

  void _resetActivity() {
    _lastActivityTime = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, _handleInactivity);
  }

  /// Handle inactivity timeout
  Future<void> _handleInactivity() async {
    if (AuthService.instance.isLoggedIn) {
      await AuthService.instance.logout();
      
      // Navigate to splash screen (which will route to sign-in) if navigator key is available
      if (_navigatorKey?.currentContext != null) {
        // Use a post-frame callback to ensure navigation happens after logout completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_navigatorKey?.currentContext != null) {
            final navigator = Navigator.of(_navigatorKey!.currentContext!);
            navigator.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const SplashScreen(),
              ),
              (route) => false,
            );
          }
        });
      }
    }
  }

  /// Check if user should be logged out based on last activity
  Future<void> checkInactivity() async {
    // Only check if user is logged in
    if (!AuthService.instance.isLoggedIn) {
      _lastActivityTime = null;
      _inactivityTimer?.cancel();
      return;
    }

    if (_lastActivityTime == null) {
      _resetActivity();
      return;
    }

    final timeSinceLastActivity = DateTime.now().difference(_lastActivityTime!);
    if (timeSinceLastActivity >= _inactivityTimeout) {
      await _handleInactivity();
    } else {
      // Reset timer for remaining time
      _inactivityTimer?.cancel();
      final remainingTime = _inactivityTimeout - timeSinceLastActivity;
      _inactivityTimer = Timer(remainingTime, _handleInactivity);
    }
  }

  /// Clean up resources
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _lastActivityTime = null;
    _isInitialized = false;
  }
}

