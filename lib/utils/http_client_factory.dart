import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Conditional imports - use platform-specific implementations
import 'http_client_factory_io.dart' if (dart.library.html) 'http_client_factory_web.dart';

/// Creates an HTTP client with appropriate SSL certificate handling
/// - For web: Uses standard HTTP client (browser handles SSL)
/// - For development URLs (localhost, private IPs): Bypasses SSL validation on non-web
/// - For production URLs: Uses standard certificate validation
http.Client createHttpClient(String url) {
  // On web, use standard HTTP client (browser handles SSL validation)
  if (kIsWeb) {
    return http.Client();
  }
  
  // Check if this is a development/local URL
  // Matches: localhost, 127.0.0.1, 10.0.2.2 (emulator), private IP ranges, and Tailscale IPs
  final isDevelopmentUrl = _isDevelopmentUrl(url);
  
  // For development URLs (including Tailscale), create a client that bypasses SSL validation
  // This allows self-signed certificates for server deployments
  // Note: This code only runs on non-web platforms (we return early if kIsWeb)
  if (isDevelopmentUrl && url.startsWith('https://')) {
    try {
      // Use platform-specific implementation (io_client on non-web, stub on web)
      return createHttpClientWithSslBypass(url);
    } catch (e) {
      // If HttpClient is not available, fallback
      return http.Client();
    }
  }
  
  // For HTTP URLs (non-HTTPS), use standard client
  if (url.startsWith('http://')) {
    return http.Client();
  }
  
  // For production HTTPS URLs, use standard HTTP client with proper certificate validation
  return http.Client();
}

/// Determines if a URL is a development/local URL
/// Returns true for localhost, loopback, emulator, private IP ranges, and Tailscale IPs
bool _isDevelopmentUrl(String url) {
  // Extract host from URL
  try {
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();
    
    // Check for localhost variants
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '0.0.0.0') {
      return true;
    }
    
    // Check for Android emulator host
    if (host == '10.0.2.2') {
      return true;
    }
    
    // Check for private IP ranges (RFC 1918) and Tailscale IPs
    // 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 (Tailscale)
    final parts = host.split('.');
    if (parts.length == 4) {
      try {
        final octet1 = int.parse(parts[0]);
        final octet2 = int.parse(parts[1]);
        
        // 10.0.0.0/8 (private IP range)
        if (octet1 == 10) return true;
        
        // 100.64.0.0/10 (Tailscale IP range - 100.64.0.0 to 100.127.255.255)
        // Actually Tailscale uses 100.x.x.x, so we check 100.0.0.0/8
        if (octet1 == 100) return true;
        
        // 172.16.0.0/12 (private IP range)
        if (octet1 == 172 && octet2 >= 16 && octet2 <= 31) return true;
        
        // 192.168.0.0/16 (private IP range)
        if (octet1 == 192 && octet2 == 168) return true;
      } catch (e) {
        // Not a valid IP, continue
      }
    }
    
    return false;
  } catch (e) {
    // If URL parsing fails, check string contains common development patterns
    return url.contains('localhost') || 
           url.contains('127.0.0.1') || 
           url.contains('10.0.2.2') ||
           url.contains('192.168.') ||
           url.contains('100.'); // Tailscale IPs
  }
}
