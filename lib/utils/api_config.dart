import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Only import dart:io on non-web platforms
// ignore: unnecessary_import
import 'dart:io' show Platform;

String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    print('🌍 Using environment variable API URL: $defined');
    return defined;
  }

  if (kIsWeb) {
    print('🌐 Web platform detected, using localhost');
    return 'http://localhost:5107';
  }

  try {
    if (Platform.isAndroid) {
      print('📱 Android platform detected');
      // For Android devices, localhost won't work on physical devices
      // Use the primary IP (your development machine) for physical devices
      final primaryUrl = getPrimaryBaseUrl();
      print('🔗 Using primary IP for Android: $primaryUrl');
      return primaryUrl;
    } else if (Platform.isIOS) {
      print('🍎 iOS platform detected, using localhost');
      return 'http://localhost:5107';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('💻 Desktop platform detected, using localhost');
      return 'http://localhost:5107';
    }
  } catch (e) {
    print('⚠️ Platform detection failed: $e');
    // Platform not available (e.g., web), ignore
  }

  print('🔄 Fallback to localhost');
  return 'http://localhost:5107';
}

// Primary and fallback IP addresses for physical devices
// Update these IPs to match your actual network configuration
const String _primaryIp = '192.168.51.207';  // Your development machine (actual IP)
const String _fallbackIp = '192.168.56.122'; // Secondary machine
const String _tertiaryIp = '10.152.206.21';  // Additional fallback machine
const int _port = 5107;

// Common network ranges to try for Android devices
const List<String> _commonNetworkRanges = [
  '192.168.1',   // Most common home router range
  '192.168.0',   // Second most common home router range
  '192.168.56',  // VirtualBox/Vagrant default range
  '10.0.0',      // Some corporate networks
  '172.16',      // Docker default range
];

String getPrimaryBaseUrl() {
  return 'http://$_primaryIp:$_port';
}

String getFallbackBaseUrl() {
  return 'http://$_fallbackIp:$_port';
}

String getTertiaryBaseUrl() {
  return 'http://$_tertiaryIp:$_port';
}

// Test connection to a URL and return true if successful
Future<bool> testConnection(String baseUrl) async {
  try {
    final uri = Uri.parse('$baseUrl/api/health');
    print('🔍 Testing connection to: $uri');
    final client = http.Client();
    
    // Increase timeout for physical devices
    final response = await client.get(uri).timeout(const Duration(seconds: 10));
    client.close();
    
    print('📡 Response status: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✅ Health check successful: ${response.body}');
      return true;
    } else {
      print('⚠️ Unexpected status code: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('❌ Connection test failed: $e');
    
    // Provide specific error guidance
    if (e.toString().contains('TimeoutException')) {
      print('⏰ Timeout - Server may be unreachable or slow to respond');
      print('💡 Try: Check if API server is running on target machine');
    } else if (e.toString().contains('SocketException')) {
      print('🔌 Socket error - Network connectivity issue');
      print('💡 Try: Verify IP address and network connection');
    } else if (e.toString().contains('Connection refused')) {
      print('🚫 Connection refused - Server not accepting connections');
      print('💡 Try: Check if API server is running and firewall settings');
    }
    
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

  print('🔍 Starting API URL resolution with fallback mechanism...');
  
  // Get platform-specific URLs to try
  List<String> urlsToTry = [];
  
  try {
    if (Platform.isAndroid) {
      print('📱 Android device detected - prioritizing network IPs');
      urlsToTry = [
        getPrimaryBaseUrl(),    // Your development machine (192.168.56.200)
        getFallbackBaseUrl(),   // Secondary machine (192.168.56.122)
        getTertiaryBaseUrl(),   // Tertiary machine (10.152.206.21)
        'http://10.0.2.2:5107', // Android emulator host IP
        'http://localhost:5107', // Only works with USB debugging
      ];
    } else {
      print('💻 Non-Android platform detected - prioritizing localhost');
      urlsToTry = [
        'http://localhost:5107',
        getPrimaryBaseUrl(),    // Your development machine
        getFallbackBaseUrl(),   // Secondary machine
        getTertiaryBaseUrl(),   // Tertiary machine
        'http://127.0.0.1:5107',
      ];
    }
  } catch (e) {
    print('⚠️ Platform detection failed, using fallback URLs: $e');
    urlsToTry = [
      'http://localhost:5107',
      getPrimaryBaseUrl(),
      getFallbackBaseUrl(),
      getTertiaryBaseUrl(),
    ];
  }

  // Test each URL in order
  for (int i = 0; i < urlsToTry.length; i++) {
    final url = urlsToTry[i];
    print('🔍 Testing URL ${i + 1}/${urlsToTry.length}: $url');
    
    final isWorking = await testConnection(url);
    if (isWorking) {
      print('✅ Successfully connected to: $url');
      return url;
    } else {
      print('❌ Failed to connect to: $url');
    }
  }

  // If all fail, return the first URL (app will handle the error)
  final fallbackUrl = urlsToTry.first;
  print('⚠️ All API URLs failed, using fallback: $fallbackUrl');
  print('💡 Make sure your EMR API server is running on one of these:');
  for (final url in urlsToTry) {
    print('   - $url');
  }
  print('🔧 Troubleshooting tips:');
  print('   - Check if API server is running on the target machine');
  print('   - Verify firewall allows connections on port 5107');
  print('   - Ensure all devices are on the same network');
  print('   - Test connectivity: ping the IP addresses');
  
  return fallbackUrl;
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
        getTertiaryBaseUrl(),   // Tertiary machine (10.152.206.21)
        'http://10.0.2.2:5107', // Android emulator host IP
        'http://localhost:5107', // Only works with USB debugging
      ];
    } else {
      // For other platforms (web, desktop)
      urls = [
        'http://localhost:5107',
        getPrimaryBaseUrl(),    // Your development machine
        getFallbackBaseUrl(),   // Secondary machine
        getTertiaryBaseUrl(),   // Tertiary machine
        'http://127.0.0.1:5107',
      ];
    }
  } catch (_) {
    // Fallback for web
    urls = [
      'http://localhost:5107',
      getPrimaryBaseUrl(),      // Your development machine
      getFallbackBaseUrl(),     // Secondary machine
      getTertiaryBaseUrl(),     // Tertiary machine
    ];
  }
  
  for (final url in urls) {
    print('Testing: $url');
    final isWorking = await testConnection(url);
    print(isWorking ? '✅ Working' : '❌ Failed');
    print('---');
  }
}

// Helper function to detect device network information
Future<void> detectDeviceNetwork() async {
  print('🔍 Detecting device network configuration...');
  
  try {
    if (Platform.isAndroid) {
      print('📱 Android device detected');
      
      // Test common Android network configurations
      final testUrls = [
        'http://192.168.51.207:5107', // Your development machine (actual IP)
        'http://10.0.2.2:5107', // Android emulator
        'http://192.168.1.1:5107', // Common router IP
        'http://192.168.0.1:5107', // Common router IP
        'http://192.168.56.1:5107', // VirtualBox default
        'http://192.168.56.122:5107', // Secondary machine
        'http://10.152.206.21:5107', // Tertiary machine
      ];
      
      print('🧪 Testing common Android network configurations...');
      for (final url in testUrls) {
        print('Testing: $url');
        final isWorking = await testConnection(url);
        if (isWorking) {
          print('✅ Found working connection: $url');
          return;
        }
      }
      
      print('❌ No working connections found');
      print('💡 Manual steps to find your network:');
      print('   1. Check your router admin panel for connected devices');
      print('   2. Find your development machine IP address');
      print('   3. Update _primaryIp in api_config.dart');
      print('   4. Ensure API server is running on port 5107');
      
      // Provide specific guidance based on the timeout error
      print('');
      print('🔧 Specific troubleshooting for timeout errors:');
      print('   - Verify API server is running: Check terminal for "Now listening on: http://0.0.0.0:5107"');
      print('   - Check Windows Firewall: Allow port 5107 through firewall');
      print('   - Verify network: Ensure device and server are on same WiFi');
      print('   - Test manually: Open browser on device and go to http://192.168.51.207:5107/api/health');
      print('   - Find correct IP: Run "ipconfig" on development machine to get actual IP');
    }
  } catch (e) {
    print('⚠️ Network detection failed: $e');
  }
}

// Helper function to get network information for debugging
void printNetworkInfo() {
  print('🌐 Network Configuration Help:');
  print('=====================================');
  
  try {
    if (Platform.isAndroid) {
      print('📱 Physical Android Device Detected');
      print('The app will try these IP addresses in order:');
      print('  1. ${getPrimaryBaseUrl()} (your development machine)');
      print('  2. ${getFallbackBaseUrl()} (secondary machine)');
      print('  3. ${getTertiaryBaseUrl()} (tertiary machine)');
      print('  4. http://10.0.2.2:5107 (Android emulator only)');
      print('  5. http://localhost:5107 (USB debugging only)');
    } else {
      print('💻 Desktop/Web Platform Detected');
      print('The app will try these URLs in order:');
      print('  1. http://localhost:5107 (local development)');
      print('  2. ${getPrimaryBaseUrl()} (your development machine)');
      print('  3. ${getFallbackBaseUrl()} (secondary machine)');
      print('  4. ${getTertiaryBaseUrl()} (tertiary machine)');
    }
  } catch (e) {
    print('⚠️ Platform detection failed: $e');
    print('Using fallback configuration...');
  }
  
  print('');
  print('🔧 Troubleshooting Steps:');
  print('1. Verify API server is running:');
  print('   - Check terminal shows: "Now listening on: http://0.0.0.0:5107"');
  print('   - Ensure server is accessible from network');
  print('');
  print('2. Check network connectivity:');
  print('   - Ensure device and server are on same WiFi network');
      print('   - Test ping: ping 192.168.51.207');
      print('   - Test ping: ping 192.168.56.122');
      print('   - Test ping: ping 10.152.206.21');
  print('');
  print('3. Verify firewall settings:');
  print('   - Allow port 5107 through Windows Firewall');
  print('   - Check if antivirus is blocking connections');
  print('');
  print('4. Test API directly:');
  print('   - Open browser on device: http://192.168.51.207:5107/api/health');
  print('   - Should return: {"status":"healthy"}');
  print('');
  print('5. Development machine IP:');
  print('   - Find your IP: ipconfig (Windows) or ifconfig (Mac/Linux)');
  print('   - Update _primaryIp in api_config.dart if needed');
  print('');
  print('📞 If issues persist, check:');
  print('   - Router settings (AP isolation disabled)');
  print('   - Network security policies');
  print('   - VPN/proxy configurations');
}


