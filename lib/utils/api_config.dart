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

  // Default to localhost:7287 for all platforms
  print('🌐 Using default API URL: http://localhost:7287');
  
  if (kIsWeb) {
    return 'http://localhost:7287';
  }

  try {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      print('📱 Android platform detected, using 10.0.2.2 for emulator (host machine localhost)');
      return 'http://10.0.2.2:7287';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost directly
      print('🍎 iOS platform detected, using localhost');
      return 'http://localhost:7287';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('💻 Desktop platform detected, using localhost');
      return 'http://localhost:7287';
    }
  } catch (e) {
    print('⚠️ Platform detection failed: $e');
    // Platform not available (e.g., web), ignore
  }

  print('🔄 Fallback to localhost');
  return 'http://localhost:7287';
}

// Primary and fallback IP addresses for physical devices
// Update these IPs to match your actual network configuration
const String _primaryIp = '172.30.163.21';   // Your development machine (test server IP)
const String _fallbackIp = '192.168.56.122'; // Secondary machine
const String _tertiaryIp = '10.152.206.21';  // Additional fallback machine
const int _port = 7287;

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

// Test connection to a URL by testing hospitals and departments endpoints
Future<bool> testConnection(String baseUrl) async {
  final client = http.Client();
  
  try {
    // Test hospitals endpoint first
    final hospitalsUri = Uri.parse('$baseUrl/api/hospitals');
    print('🔍 Testing connection to: $hospitalsUri');
    
    final hospitalsResponse = await client.get(hospitalsUri).timeout(const Duration(seconds: 10));
    
    print('📡 Hospitals endpoint status: ${hospitalsResponse.statusCode}');
    
    // If hospitals endpoint works, try departments endpoint
    if (hospitalsResponse.statusCode >= 200 && hospitalsResponse.statusCode < 300) {
      final departmentsUri = Uri.parse('$baseUrl/api/departments');
      print('🔍 Testing departments endpoint: $departmentsUri');
      
      final departmentsResponse = await client.get(departmentsUri).timeout(const Duration(seconds: 10));
      
      print('📡 Departments endpoint status: ${departmentsResponse.statusCode}');
      
      if (departmentsResponse.statusCode >= 200 && departmentsResponse.statusCode < 300) {
        print('✅ Connection test successful - Both hospitals and departments endpoints are working');
        client.close();
        return true;
      } else {
        print('⚠️ Hospitals endpoint works but departments returned: ${departmentsResponse.statusCode}');
        client.close();
        return false;
      }
    } else {
      print('⚠️ Hospitals endpoint returned unexpected status: ${hospitalsResponse.statusCode}');
      client.close();
      return false;
    }
  } catch (e) {
    print('❌ Connection test failed: $e');
    client.close();
    
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
      print('📱 Android device detected - prioritizing emulator host (10.0.2.2)');
      urlsToTry = [
        'http://10.0.2.2:7287', // Android emulator special IP for host machine
        'http://localhost:7287', // Fallback for physical devices
        'http://127.0.0.1:7287',
        getPrimaryBaseUrl(),    // Your development machine (172.30.163.21)
        getFallbackBaseUrl(),   // Secondary machine (192.168.56.122)
        getTertiaryBaseUrl(),   // Tertiary machine (10.152.206.21)
      ];
    } else {
      print('💻 Non-Android platform detected - prioritizing localhost');
      urlsToTry = [
        'http://localhost:7287', // Default
        'http://127.0.0.1:7287',
        getPrimaryBaseUrl(),    // Your development machine
        getFallbackBaseUrl(),   // Secondary machine
        getTertiaryBaseUrl(),   // Tertiary machine
      ];
    }
  } catch (e) {
    print('⚠️ Platform detection failed, using fallback URLs: $e');
    urlsToTry = [
      'http://localhost:7287', // Default
      'http://127.0.0.1:7287',
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
  print('   - Verify firewall allows connections on port 7287');
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
      // For Android devices/emulators
      urls = [
        'http://10.0.2.2:7287', // Android emulator special IP for host machine
        'http://localhost:7287', // For physical Android devices
        'http://127.0.0.1:7287',
        getPrimaryBaseUrl(),    // Your development machine (172.30.163.21)
        getFallbackBaseUrl(),   // Secondary machine (192.168.56.122)
        getTertiaryBaseUrl(),   // Tertiary machine (10.152.206.21)
      ];
    } else {
      // For other platforms (web, desktop, iOS)
      urls = [
        'http://localhost:7287',
        'http://127.0.0.1:7287',
        getPrimaryBaseUrl(),    // Your development machine
        getFallbackBaseUrl(),   // Secondary machine
        getTertiaryBaseUrl(),   // Tertiary machine
      ];
    }
  } catch (_) {
    // Fallback for web
    urls = [
      'http://localhost:7287',
      'http://127.0.0.1:7287',
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
      
      // Test common network configurations
      final testUrls = [
        'http://10.0.2.2:7287', // Android emulator special IP for host machine
        'http://localhost:7287', // For physical Android devices
        'http://127.0.0.1:7287',
        'http://172.30.163.21:7287', // Your development machine (test server IP)
        'http://192.168.56.122:7287', // Secondary machine
        'http://10.152.206.21:7287', // Tertiary machine
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
      print('   4. Ensure API server is running on port 7287');
      
      // Provide specific guidance based on the timeout error
      print('');
      print('🔧 Specific troubleshooting for timeout errors:');
      print('   - Verify API server is running: Check terminal for "Now listening on: http://0.0.0.0:7287"');
      print('   - Check Windows Firewall: Allow port 7287 through firewall');
      print('   - Verify network: Ensure device and server are on same WiFi');
      print('   - Test manually: Open browser and go to http://localhost:7287/api/hospitals');
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
      print('📱 Android Device/Emulator Detected');
      print('The app will try these IP addresses in order:');
      print('  1. http://10.0.2.2:7287 (Android emulator - host machine)');
      print('  2. http://localhost:7287 (physical Android device)');
      print('  3. ${getPrimaryBaseUrl()} (your development machine)');
      print('  4. ${getFallbackBaseUrl()} (secondary machine)');
      print('  5. ${getTertiaryBaseUrl()} (tertiary machine)');
      print('');
      print('💡 Note: 10.0.2.2 is the special IP that Android emulators use');
      print('   to access the host machine\'s localhost.');
    } else {
      print('💻 Desktop/Web/iOS Platform Detected');
      print('The app will try these URLs in order:');
      print('  1. http://localhost:7287 (local development)');
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
  print('   - Check terminal shows: "Now listening on: http://0.0.0.0:7287"');
  print('   - Ensure server is accessible from network');
  print('');
  print('2. Check network connectivity:');
  print('   - Android Emulator: Use http://10.0.2.2:7287 (maps to host localhost)');
  print('   - Physical Android/iOS: Use http://localhost:7287 or network IP');
  print('   - Desktop/Web: Use http://localhost:7287');
  print('   - For network access: Ensure device and server are on same WiFi network');
      print('   - Test ping: ping 172.30.163.21');
      print('   - Test ping: ping 192.168.56.122');
      print('   - Test ping: ping 10.152.206.21');
  print('');
  print('3. Verify firewall settings:');
  print('   - Allow port 7287 through Windows Firewall');
  print('   - Check if antivirus is blocking connections');
  print('');
  print('4. Test API directly:');
  print('   - Local: Open browser and go to http://localhost:7287/api/hospitals');
  print('   - Network: Open browser and go to http://172.30.163.21:7287/api/hospitals');
  print('   - Should return a list of hospitals');
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


