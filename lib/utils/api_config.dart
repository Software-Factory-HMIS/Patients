import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'dart:io' show Platform;

/// Production HMIS API host (no trailing slash). Paths in clients use `$baseUrl/api/...`.
const String _productionEmrBaseUrl = 'https://hmis-api.pshealthpunjab.gov.pk';

/// API Configuration for EMR Backend Service
///
/// Priority:
/// 1. `EMR_BASE_URL` (--dart-define=EMR_BASE_URL=...)
/// 2. Release/profile builds: [_productionEmrBaseUrl]
/// 3. Debug: platform localhost defaults for local backend development

String resolveEmrBaseUrl() {
  const String defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) {
    return defined;
  }

  if (!kDebugMode) {
    return _productionEmrBaseUrl;
  }

  if (kIsWeb) {
    return 'https://localhost:7287';
  } else if (Platform.isAndroid) {
    return 'https://10.0.2.2:7287';
  } else if (Platform.isIOS) {
    return 'https://localhost:7287';
  }
  return 'https://localhost:7287';
}


