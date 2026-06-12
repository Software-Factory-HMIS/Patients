import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io' show Platform;

// ─── HMIS_Prod (core API — EMR data, OTP verify, JWT) ────────────────────────

/// Production HMIS_Prod host. Handles OTP verify, JWT, and all EMR data.
const String _productionEmrBaseUrl = 'http://100.98.154.101/HMIS';

/// Resolves the base URL for HMIS_Prod.
///
/// Priority:
/// 1. `--dart-define=EMR_BASE_URL=...`
/// 2. Release/profile builds → production host
/// 3. Debug → localhost:7287
String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) return defined;

  if (!kDebugMode) return _productionEmrBaseUrl;

  if (kIsWeb) return 'https://localhost:7287';
  if (Platform.isAndroid) return 'https://10.0.2.2:7287';
  return 'https://localhost:7287';
}

// ─── HMIS_AuthServer (OTP gateway — lookup + OTP send only) ──────────────────

/// Production HMIS_AuthServer host. Handles patient lookup and OTP delivery only.
const String _productionAuthServerBaseUrl = 'http://100.98.154.101:8080/HMIS_AuthServer';

/// Resolves the base URL for HMIS_AuthServer.
///
/// Priority:
/// 1. `--dart-define=AUTH_SERVER_BASE_URL=...`
/// 2. Release/profile builds → production host
/// 3. Debug → localhost:7143
String resolveAuthServerBaseUrl() {
  const String defined = String.fromEnvironment('AUTH_SERVER_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) return defined;

  if (!kDebugMode) return _productionAuthServerBaseUrl;

  if (kIsWeb) return 'http://localhost:5045';
  if (Platform.isAndroid) return 'http://10.0.2.2:5045';
  return 'http://localhost:5045';
}


