// Platform-specific HTTP client for native platforms (Android, iOS, desktop)
// This file is used when dart:io is available

import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an HTTP client for native platforms
/// Bypasses SSL validation only in debug builds for local/dev HTTPS (self-signed).
http.Client createHttpClient(String url, bool isDevelopmentUrl) {
  if (kDebugMode && isDevelopmentUrl && url.startsWith('https://')) {
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // WARNING: Only bypasses SSL for development URLs
        // This allows self-signed certificates in development environments
        // Safe for emulator and local network testing on real devices
        return true;
      };
    return IOClient(httpClient);
  }

  // For production URLs, use standard HTTP client with proper certificate validation
  return http.Client();
}
