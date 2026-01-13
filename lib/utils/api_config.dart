import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

/// API Configuration for EMR Backend Service
/// 
/// This module provides the production backend URL configuration.
/// The backend URL can be overridden using the EMR_BASE_URL environment variable
/// during build time for different deployment environments.
/// 
/// Default URLs:
/// - Web: https://localhost:7287
/// - Android Emulator: https://10.0.2.2:7287 (10.0.2.2 maps to host machine's localhost)
/// - Android Physical Device: Use your machine's IP address (e.g., https://192.168.1.100:7287)
/// - iOS Simulator: https://localhost:7287
/// - iOS Physical Device: Use your machine's IP address

/// Resolves the EMR base URL for API connections.
/// 
/// Priority:
/// 1. EMR_BASE_URL environment variable (if set during build)
/// 2. Platform-specific default URL
/// 
/// Returns the base URL string for the EMR API service.
String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    return defined;
  }

  // Platform-specific defaults
  if (kIsWeb) {
    // Web platform - use localhost
    return 'https://localhost:7287';
  } else if (Platform.isAndroid) {
    // Android - use 10.0.2.2 which maps to host machine's localhost in emulator
    // For physical devices, you'll need to use your machine's actual IP address
    return 'https://10.0.2.2:7287';
  } else if (Platform.isIOS) {
    // iOS Simulator - use localhost
    // For physical devices, you'll need to use your machine's actual IP address
    return 'https://localhost:7287';
  } else {
    // Desktop platforms (Windows, macOS, Linux) - use localhost
    return 'https://localhost:7287';
  }
}


