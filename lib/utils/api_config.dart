import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Only import dart:io on non-web platforms
// ignore: unnecessary_import
import 'dart:io' show Platform;

String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) return defined;

  if (kIsWeb) {
    return 'http://localhost:5107';
  }

  try {
    if (Platform.isAndroid) {
      // For Android devices, try localhost first (works with USB debugging)
      // If that fails, the app will handle the error gracefully
      return 'http://localhost:5107';
    }
  } catch (_) {
    // Platform not available (e.g., web), ignore
  }

  return 'http://localhost:5107';
}

// Fallback IP address for when localhost doesn't work
const String _fallbackIp = '192.168.56.122';
const int _port = 5107;

String getFallbackBaseUrl() {
  return 'http://$_fallbackIp:$_port';
}

// Test connection to a URL and return true if successful
Future<bool> testConnection(String baseUrl) async {
  try {
    final uri = Uri.parse('$baseUrl/api/health');
    final client = http.Client();
    final response = await client.get(uri).timeout(const Duration(seconds: 3));
    client.close();
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// Resolve EMR base URL with fallback mechanism
Future<String> resolveEmrBaseUrlWithFallback() async {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) return defined;

  // Try the default URL first
  final defaultUrl = resolveEmrBaseUrl();
  final isDefaultWorking = await testConnection(defaultUrl);
  
  if (isDefaultWorking) {
    print('✅ Using default API URL: $defaultUrl');
    return defaultUrl;
  }

  // If default doesn't work, try the fallback IP
  final fallbackUrl = getFallbackBaseUrl();
  final isFallbackWorking = await testConnection(fallbackUrl);
  
  if (isFallbackWorking) {
    print('✅ Using fallback API URL: $fallbackUrl');
    return fallbackUrl;
  }

  // If both fail, return default (app will handle the error)
  print('⚠️ Both default and fallback URLs failed, using default: $defaultUrl');
  return defaultUrl;
}


