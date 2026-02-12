// Platform-specific HTTP client for web platform
// This file is used when dart:io is NOT available (web)

import 'package:http/http.dart' as http;

/// Creates an HTTP client for web platform
/// On web, SSL is handled by the browser, so we just return a standard client
http.Client createHttpClient(String url, bool isDevelopmentUrl) {
  // On web, the browser handles SSL certificates
  // Always use standard HTTP client
  return http.Client();
}
