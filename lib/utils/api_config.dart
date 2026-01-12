import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Only import dart:io on non-web platforms
// ignore: unnecessary_import
import 'dart:io' show Platform;

/// API Configuration for EMR Backend Connection
/// 
/// CONFIGURATION GUIDE FOR PHYSICAL DEVICES:
/// ==========================================
/// 
/// 1. Find your computer's IP address:
///    - Windows: Run "ipconfig" in PowerShell/CMD
///    - Mac/Linux: Run "ifconfig" in terminal
///    - Look for IPv4 address (e.g., 192.168.1.100)
/// 
/// 2. Update the IP addresses below:
///    - Set _primaryIp to your computer's IP (e.g., '192.168.1.100')
///    - Leave empty to auto-detect from common network ranges
/// 
/// 3. Ensure backend is configured:
///    - Backend must listen on 0.0.0.0:7287 (not just localhost)
///    - Allow port 7287 through Windows Firewall
/// 
/// 4. Network requirements:
///    - Device and computer must be on the same WiFi network
///    - Disable VPN if active
///    - Check router doesn't have AP Isolation enabled
/// 
/// 5. Alternative: Use environment variable:
///    flutter run --dart-define=EMR_BASE_URL=http://192.168.1.100:7287
/// 
/// The app will automatically try multiple IPs if _primaryIp is empty,
/// but setting it explicitly is faster and more reliable.

String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    print('🌍 Using environment variable API URL: $defined');
    return defined;
  }

  // Default to localhost:7287 for all platforms
  print('🌐 Using default API URL: http://localhost:$_port');
  
  if (kIsWeb) {
    return 'http://localhost:$_port';
  }

  try {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      // Note: For physical devices, this won't work - use resolveEmrBaseUrlWithFallback() instead
      print('📱 Android platform detected, using 10.0.2.2 for emulator (host machine localhost)');
      print('💡 For physical devices, use resolveEmrBaseUrlWithFallback() for network IP detection');
      return 'http://10.0.2.2:$_port';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost directly
      print('🍎 iOS platform detected, using localhost');
      return 'http://localhost:$_port';
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      print('💻 Desktop platform detected, using localhost');
      return 'http://localhost:$_port';
    }
  } catch (e) {
    print('⚠️ Platform detection failed: $e');
    // Platform not available (e.g., web), ignore
  }

  print('🔄 Fallback to localhost');
  return 'http://localhost:$_port';
}

// Primary and fallback IP addresses for physical devices
// Update these IPs to match your actual network configuration
// Set to empty string to auto-detect or use environment variable
const String _primaryIp = '103.86.133.38';   // Backend server IP
const String _fallbackIp = '';  // Leave empty or set secondary IP
const String _tertiaryIp = '';  // Leave empty or set tertiary IP
const int _port = 7287;

// Common network ranges to try for Android devices
const List<String> _commonNetworkRanges = [
  '192.168.1',   // Most common home router range
  '192.168.0',   // Second most common home router range
  '192.168.56',  // VirtualBox/Vagrant default range
  '10.0.0',      // Some corporate networks
  '172.16',      // Docker default range
  '172.30',      // Additional common range
];

// Generate potential IPs from common network ranges
// This helps physical devices find the backend automatically
List<String> _generateCommonNetworkIps() {
  final List<String> ips = [];
  
  // Add configured IPs first if they exist (with http:// prefix)
  if (_primaryIp.isNotEmpty) {
    ips.add('http://$_primaryIp:$_port');
  }
  if (_fallbackIp.isNotEmpty) {
    ips.add('http://$_fallbackIp:$_port');
  }
  if (_tertiaryIp.isNotEmpty) {
    ips.add('http://$_tertiaryIp:$_port');
  }
  
  // Generate common IPs from network ranges
  // Test common host numbers that are typically used for development machines
  final commonHosts = [100, 101, 102, 103, 104, 105, 1, 2, 3, 4, 5, 10, 20, 50];
  
  for (final range in _commonNetworkRanges) {
    for (final host in commonHosts) {
      if (range.contains('.')) {
        // Already has subnet (e.g., '192.168.1'), just add host
        ips.add('http://$range.$host:$_port');
      } else if (range == '172.16' || range == '172.30') {
        // Special case for 172.x.x.x ranges - need two octets
        ips.add('http://$range.0.$host:$_port');
      } else {
        // For ranges like '10.0.0', construct properly
        ips.add('http://$range.$host:$_port');
      }
    }
  }
  
  // Remove duplicates while preserving order
  return ips.toSet().toList();
}

String getPrimaryBaseUrl() {
  if (_primaryIp.isEmpty) return '';
  return 'http://$_primaryIp:$_port';
}

String getFallbackBaseUrl() {
  if (_fallbackIp.isEmpty) return '';
  return 'http://$_fallbackIp:$_port';
}

String getTertiaryBaseUrl() {
  if (_tertiaryIp.isEmpty) return '';
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
      print('💡 Troubleshooting:');
      print('   1. Verify backend server is running on 103.86.133.38:7287');
      print('   2. Check if server is listening on 0.0.0.0:7287 (not just localhost)');
      print('   3. Test from browser: http://103.86.133.38:7287/api/hospitals');
      print('   4. Check network connectivity and firewall rules');
    } else if (e.toString().contains('SocketException')) {
      print('🔌 Socket error - Network connectivity issue');
      if (e.toString().contains('Connection refused')) {
        print('🚫 Connection refused - Server not accepting connections');
        print('💡 Troubleshooting for 103.86.133.38:7287:');
        print('   1. Verify backend server is running and accessible');
        print('   2. Check server is listening on 0.0.0.0:7287 (not just 127.0.0.1)');
        print('   3. Verify firewall allows incoming connections on port 7287');
        print('   4. Test from browser: http://103.86.133.38:7287/api/hospitals');
        print('   5. Check server logs for startup message: "Now listening on: http://0.0.0.0:7287"');
        print('   6. Ensure backend CORS is configured to allow all origins');
      } else {
        print('💡 Try: Verify IP address (103.86.133.38) and network connection');
        print('   - Test ping: ping 103.86.133.38');
        print('   - Test from browser: http://103.86.133.38:7287/api/hospitals');
      }
    } else if (e.toString().contains('Connection refused')) {
      print('🚫 Connection refused - Server not accepting connections');
      print('💡 Troubleshooting for 103.86.133.38:7287:');
      print('   1. Verify backend server is running and accessible');
      print('   2. Check server is listening on 0.0.0.0:7287 (not just 127.0.0.1)');
      print('   3. Verify firewall allows incoming connections on port 7287');
      print('   4. Test from browser: http://103.86.133.38:7287/api/hospitals');
      print('   5. Check server logs for startup message: "Now listening on: http://0.0.0.0:7287"');
      print('   6. Ensure backend CORS is configured to allow all origins');
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
      print('📱 Android device detected');
      
      // For Android, we need to distinguish between emulator and physical device
      // Emulator: Use 10.0.2.2 (maps to host localhost)
      // Physical device: Need actual network IP (localhost won't work)
      
      // Start with emulator IP (works for emulator)
      urlsToTry.add('http://10.0.2.2:$_port');
      
      // Add configured IPs if they exist
      if (_primaryIp.isNotEmpty) {
        urlsToTry.add('http://$_primaryIp:$_port');
      }
      if (_fallbackIp.isNotEmpty) {
        urlsToTry.add('http://$_fallbackIp:$_port');
      }
      if (_tertiaryIp.isNotEmpty) {
        urlsToTry.add('http://$_tertiaryIp:$_port');
      }
      
      // For physical devices, generate common network IPs
      // This helps auto-detect the backend on the same network
      final networkIps = _generateCommonNetworkIps();
      // Add network IPs (skip duplicates)
      for (final ip in networkIps) {
        if (!urlsToTry.contains(ip)) {
          urlsToTry.add(ip);
        }
      }
      
      // Add localhost as last resort (won't work on physical device but good for testing)
      urlsToTry.add('http://localhost:$_port');
      urlsToTry.add('http://127.0.0.1:$_port');
      
      print('📋 Will try ${urlsToTry.length} URLs (emulator + network IPs)');
    } else {
      print('💻 Non-Android platform detected - prioritizing localhost');
      urlsToTry = [
        'http://localhost:$_port', // Default
        'http://127.0.0.1:$_port',
      ];
      
      // Add configured IPs if they exist
      if (_primaryIp.isNotEmpty) {
        urlsToTry.add('http://$_primaryIp:$_port');
      }
      if (_fallbackIp.isNotEmpty) {
        urlsToTry.add('http://$_fallbackIp:$_port');
      }
      if (_tertiaryIp.isNotEmpty) {
        urlsToTry.add('http://$_tertiaryIp:$_port');
      }
    }
  } catch (e) {
    print('⚠️ Platform detection failed, using fallback URLs: $e');
    urlsToTry = [
      'http://localhost:$_port', // Default
      'http://127.0.0.1:$_port',
    ];
    
    // Add configured IPs if they exist
    if (_primaryIp.isNotEmpty) {
      urlsToTry.add('http://$_primaryIp:$_port');
    }
    if (_fallbackIp.isNotEmpty) {
      urlsToTry.add('http://$_fallbackIp:$_port');
    }
    if (_tertiaryIp.isNotEmpty) {
      urlsToTry.add('http://$_tertiaryIp:$_port');
    }
  }

  // Limit the number of URLs to test to avoid long delays
  // Prioritize the first 20 URLs (emulator + configured + most common network IPs)
  final urlsToTest = urlsToTry.take(20).toList();
  
  print('🧪 Testing ${urlsToTest.length} URLs (limited from ${urlsToTry.length} total)...');
  
  // Test each URL in order
  for (int i = 0; i < urlsToTest.length; i++) {
    final url = urlsToTest[i];
    print('🔍 Testing URL ${i + 1}/${urlsToTest.length}: $url');
    
    final isWorking = await testConnection(url);
    if (isWorking) {
      print('✅ Successfully connected to: $url');
      return url;
    } else {
      print('❌ Failed to connect to: $url');
    }
  }

  // If all fail, return the first URL (app will handle the error)
  final fallbackUrl = urlsToTest.first;
  print('⚠️ All tested API URLs failed, using fallback: $fallbackUrl');
  print('💡 Make sure your EMR API server is running and accessible');
  print('🔧 Quick setup steps:');
  print('   1. Find your computer IP: Run "ipconfig" (Windows) or "ifconfig" (Mac/Linux)');
  print('   2. Update _primaryIp in api_config.dart with your IP (e.g., "192.168.1.100")');
  print('   3. Ensure backend is listening on 0.0.0.0:$_port (not just localhost)');
  print('   4. Allow port $_port through Windows Firewall');
  print('   5. Ensure device and computer are on the same WiFi network');
  print('   6. Test in browser: http://YOUR_IP:$_port/api/hospitals');
  
  return fallbackUrl;
}

// Helper function to test all possible URLs
Future<void> testAllUrls() async {
  print('🧪 Testing all possible API URLs...');
  
  List<String> urls = [];
  
  try {
    if (Platform.isAndroid) {
      // For Android devices/emulators
      urls.add('http://10.0.2.2:$_port'); // Android emulator special IP for host machine
      
      // Add configured IPs if they exist
      if (_primaryIp.isNotEmpty) {
        urls.add('http://$_primaryIp:$_port');
      }
      if (_fallbackIp.isNotEmpty) {
        urls.add('http://$_fallbackIp:$_port');
      }
      if (_tertiaryIp.isNotEmpty) {
        urls.add('http://$_tertiaryIp:$_port');
      }
      
      // Add common network IPs (limited to first 10 for testing)
      final networkIps = _generateCommonNetworkIps();
      urls.addAll(networkIps.take(10));
      
      // Add localhost as last resort
      urls.add('http://localhost:$_port');
      urls.add('http://127.0.0.1:$_port');
    } else {
      // For other platforms (web, desktop, iOS)
      urls = [
        'http://localhost:$_port',
        'http://127.0.0.1:$_port',
      ];
      
      // Add configured IPs if they exist
      if (_primaryIp.isNotEmpty) {
        urls.add('http://$_primaryIp:$_port');
      }
      if (_fallbackIp.isNotEmpty) {
        urls.add('http://$_fallbackIp:$_port');
      }
      if (_tertiaryIp.isNotEmpty) {
        urls.add('http://$_tertiaryIp:$_port');
      }
    }
  } catch (_) {
    // Fallback for web
    urls = [
      'http://localhost:$_port',
      'http://127.0.0.1:$_port',
    ];
    
    // Add configured IPs if they exist
    if (_primaryIp.isNotEmpty) {
      urls.add('http://$_primaryIp:$_port');
    }
    if (_fallbackIp.isNotEmpty) {
      urls.add('http://$_fallbackIp:$_port');
    }
    if (_tertiaryIp.isNotEmpty) {
      urls.add('http://$_tertiaryIp:$_port');
    }
  }
  
  // Remove empty strings and duplicates
  urls = urls.where((url) => url.isNotEmpty).toSet().toList();
  
  print('📋 Testing ${urls.length} URLs...');
  for (int i = 0; i < urls.length; i++) {
    final url = urls[i];
    print('Testing ${i + 1}/${urls.length}: $url');
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
      
      // Build test URLs list
      final testUrls = <String>[];
      
      // Start with emulator IP
      testUrls.add('http://10.0.2.2:$_port');
      
      // Add configured IPs if they exist
      if (_primaryIp.isNotEmpty) {
        testUrls.add('http://$_primaryIp:$_port');
      }
      if (_fallbackIp.isNotEmpty) {
        testUrls.add('http://$_fallbackIp:$_port');
      }
      if (_tertiaryIp.isNotEmpty) {
        testUrls.add('http://$_tertiaryIp:$_port');
      }
      
      // Add common network IPs (limited to first 15 for faster testing)
      final networkIps = _generateCommonNetworkIps();
      testUrls.addAll(networkIps.take(15));
      
      print('🧪 Testing ${testUrls.length} network configurations...');
      for (int i = 0; i < testUrls.length; i++) {
        final url = testUrls[i];
        print('Testing ${i + 1}/${testUrls.length}: $url');
        final isWorking = await testConnection(url);
        if (isWorking) {
          print('✅ Found working connection: $url');
          print('');
          print('💡 To use this IP permanently:');
          print('   1. Update _primaryIp in api_config.dart with: ${url.replaceAll("http://", "").replaceAll(":$_port", "")}');
          print('   2. Or use: flutter run --dart-define=EMR_BASE_URL=$url');
          return;
        }
      }
      
      print('❌ No working connections found');
      print('');
      print('💡 Manual setup steps:');
      print('   1. Find your computer IP:');
      print('      - Windows: Run "ipconfig" → Look for IPv4 Address');
      print('      - Mac/Linux: Run "ifconfig" → Look for inet address');
      print('   2. Update api_config.dart:');
      print('      - Set _primaryIp = \'YOUR_IP\' (e.g., \'192.168.1.100\')');
      print('   3. Verify backend:');
      print('      - Check terminal shows: "Now listening on: http://0.0.0.0:$_port"');
      print('      - Test in browser: http://YOUR_IP:$_port/api/hospitals');
      print('   4. Configure firewall:');
      print('      - Allow port $_port through Windows Firewall');
      print('   5. Network check:');
      print('      - Ensure device and computer are on same WiFi');
      print('      - Disable VPN if active');
    } else {
      print('💻 Non-Android platform - using localhost');
      final localhostUrl = 'http://localhost:$_port';
      print('Testing: $localhostUrl');
      final isWorking = await testConnection(localhostUrl);
      if (isWorking) {
        print('✅ Localhost connection works!');
      } else {
        print('❌ Localhost connection failed');
        print('💡 Check if backend is running on port $_port');
      }
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
      print('');
      print('Connection Priority:');
      print('  1. http://10.0.2.2:$_port (Android emulator - maps to host localhost)');
      if (_primaryIp.isNotEmpty) {
        print('  2. http://$_primaryIp:$_port (configured primary IP)');
      } else {
        print('  2. Auto-detected network IPs from common ranges');
      }
      if (_fallbackIp.isNotEmpty) {
        print('  3. http://$_fallbackIp:$_port (configured fallback IP)');
      }
      if (_tertiaryIp.isNotEmpty) {
        print('  4. http://$_tertiaryIp:$_port (configured tertiary IP)');
      }
      print('  5. Common network IPs (192.168.x.x, 10.0.x.x, etc.)');
      print('  6. http://localhost:$_port (last resort - won\'t work on physical device)');
      print('');
      print('💡 For Physical Devices:');
      print('   - localhost/127.0.0.1 will NOT work');
      print('   - You need your computer\'s network IP (e.g., 192.168.1.100)');
      print('   - Set _primaryIp in api_config.dart with your IP');
      print('   - Or use: flutter run --dart-define=EMR_BASE_URL=http://YOUR_IP:$_port');
    } else {
      print('💻 Desktop/Web/iOS Platform Detected');
      print('The app will try these URLs in order:');
      print('  1. http://localhost:$_port (local development)');
      if (_primaryIp.isNotEmpty) {
        print('  2. http://$_primaryIp:$_port (configured primary IP)');
      }
      if (_fallbackIp.isNotEmpty) {
        print('  3. http://$_fallbackIp:$_port (configured fallback IP)');
      }
      if (_tertiaryIp.isNotEmpty) {
        print('  4. http://$_tertiaryIp:$_port (configured tertiary IP)');
      }
    }
  } catch (e) {
    print('⚠️ Platform detection failed: $e');
    print('Using fallback configuration...');
  }
  
  print('');
  print('🔧 Quick Setup for Physical Devices:');
  print('1. Find your computer IP:');
  print('   - Windows: Run "ipconfig" → Look for IPv4 Address');
  print('   - Mac/Linux: Run "ifconfig" → Look for inet address');
  print('');
  print('2. Update api_config.dart:');
  print('   - Set _primaryIp = \'YOUR_IP\' (e.g., \'192.168.1.100\')');
  print('   - Or leave empty to auto-detect (slower but works)');
  print('');
  print('3. Configure Backend:');
  print('   - Ensure backend listens on 0.0.0.0:$_port (not just localhost)');
  print('   - Check startup log: "Now listening on: http://0.0.0.0:$_port"');
  print('');
  print('4. Configure Firewall:');
  print('   - Windows: Allow port $_port through Windows Firewall');
  print('   - PowerShell (Admin): New-NetFirewallRule -DisplayName "HMIS API" -Direction Inbound -LocalPort $_port -Protocol TCP -Action Allow');
  print('');
  print('5. Test Connection:');
  print('   - From computer browser: http://localhost:$_port/api/hospitals');
  print('   - From device browser: http://YOUR_IP:$_port/api/hospitals');
  print('   - Both should return JSON data');
  print('');
  print('6. Network Requirements:');
  print('   - Device and computer must be on same WiFi network');
  print('   - Disable VPN if active');
  print('   - Check router doesn\'t have AP Isolation enabled');
  print('');
  print('📞 If issues persist:');
  print('   - Verify both devices on same network');
  print('   - Check router settings (AP isolation)');
  print('   - Test ping from device to computer IP');
  print('   - Check antivirus/firewall isn\'t blocking');
}


