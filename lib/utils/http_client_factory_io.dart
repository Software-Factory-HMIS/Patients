// Non-web implementation using dart:io
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates an HTTP client with SSL bypass for development URLs (non-web only)
http.Client createHttpClientWithSslBypass(String url) {
  final httpClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      // WARNING: Only bypasses SSL for development URLs
      // This allows self-signed certificates in development environments
      return true;
    };
  return IOClient(httpClient);
}
