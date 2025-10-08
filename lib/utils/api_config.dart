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
      // For Android devices, localhost won't work on physical devices
      // Use the primary IP (your development machine) for physical devices
      return getPrimaryBaseUrl();
    }
  } catch (_) {
    // Platform not available (e.g., web), ignore
  }

  return 'http://localhost:5107';
}

// Primary and fallback IP addresses for physical devices
const String _primaryIp = '192.168.56.200';  // Your development machine
const String _fallbackIp = '192.168.56.122'; // Secondary machine
const int _port = 5107;

String getPrimaryBaseUrl() {
  return 'http://$_primaryIp:$_port';
}

String getFallbackBaseUrl() {
  return 'http://$_fallbackIp:$_port';
}

// Test connection to a URL and return true if successful
Future<bool> testConnection(String baseUrl) async {
  try {
    final uri = Uri.parse('$baseUrl/api/health');
    print('🔍 Testing connection to: $uri');
    final client = http.Client();
    final response = await client.get(uri).timeout(const Duration(seconds: 5));
    client.close();
    print('📡 Response status: ${response.statusCode}');
    return response.statusCode == 200;
  } catch (e) {
    print('❌ Connection test failed: $e');
    return false;
  }
}

// Resolve EMR base URL with fallback mechanism
Future<String> resolveEmrBaseUrlWithFallback() async {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    print('🌍 Using environment variable API URL: $defined');
    return defined;
  }

  // Try the default URL first
  final defaultUrl = resolveEmrBaseUrl();
  print('🔍 Testing default API URL: $defaultUrl');
  final isDefaultWorking = await testConnection(defaultUrl);
  
  if (isDefaultWorking) {
    print('✅ Using default API URL: $defaultUrl');
    return defaultUrl;
  }

  print('❌ Default URL failed, trying fallback IPs...');

  // Try primary IP first (your development machine)
  final primaryUrl = getPrimaryBaseUrl();
  print('🔍 Testing primary API URL: $primaryUrl');
  final isPrimaryWorking = await testConnection(primaryUrl);
  
  if (isPrimaryWorking) {
    print('✅ Using primary API URL: $primaryUrl');
    return primaryUrl;
  }

  // If primary doesn't work, try the secondary IP
  final fallbackUrl = getFallbackBaseUrl();
  print('🔍 Testing secondary API URL: $fallbackUrl');
  final isFallbackWorking = await testConnection(fallbackUrl);
  
  if (isFallbackWorking) {
    print('✅ Using secondary API URL: $fallbackUrl');
    return fallbackUrl;
  }

  // If all fail, return default (app will handle the error)
  print('⚠️ All API URLs failed, using default: $defaultUrl');
  print('💡 Make sure your EMR API server is running on one of these:');
  print('   - $defaultUrl');
  print('   - $primaryUrl (your development machine)');
  print('   - $fallbackUrl (secondary machine)');
  return defaultUrl;
}

// Helper function to test all possible URLs
Future<void> testAllUrls() async {
  print('🧪 Testing all possible API URLs...');
  
  List<String> urls;
  
  try {
    if (Platform.isAndroid) {
      // For Android devices, focus on network IPs
      urls = [
        getPrimaryBaseUrl(),    // Your development machine (192.168.56.200)
        getFallbackBaseUrl(),   // Secondary machine (192.168.56.122)
        'http://10.0.2.2:5107', // Android emulator host IP
        'http://localhost:5107', // Only works with USB debugging
      ];
    } else {
      // For other platforms (web, desktop)
      urls = [
        'http://localhost:5107',
        getPrimaryBaseUrl(),    // Your development machine
        getFallbackBaseUrl(),   // Secondary machine
        'http://127.0.0.1:5107',
      ];
    }
  } catch (_) {
    // Fallback for web
    urls = [
      'http://localhost:5107',
      getPrimaryBaseUrl(),      // Your development machine
      getFallbackBaseUrl(),     // Secondary machine
    ];
  }
  
  for (final url in urls) {
    print('Testing: $url');
    final isWorking = await testConnection(url);
    print(isWorking ? '✅ Working' : '❌ Failed');
    print('---');
  }
}

// Helper function to get network information for debugging
void printNetworkInfo() {
  print('🌐 Network Configuration Help:');
  print('For physical devices, the app will try these IP addresses in order:');
  print('  1. ${getPrimaryBaseUrl()} (your development machine)');
  print('  2. ${getFallbackBaseUrl()} (secondary machine)');
  print('');
  print('Make sure your EMR API server is running on one of these machines.');
  print('Both machines should be accessible from the network.');
  print('');
  print('Troubleshooting:');
  print('  - Check if the API server is running on the target machine');
  print('  - Verify firewall allows connections on port 5107');
  print('  - Ensure both devices are on the same network');
  print('  - Test connectivity: ping 192.168.56.200 and ping 192.168.56.122');
}


