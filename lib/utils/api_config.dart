import 'package:flutter/foundation.dart';

// ─── Production hosts ────────────────────────────────────────────────────────

/// HMIS_Prod — OTP verify, JWT, and all EMR data.
const String productionEmrBaseUrl = 'https://hmis-api.pshealthpunjab.gov.pk';

/// HMIS_AuthServer — patient lookup + OTP delivery only.
const String productionAuthServerBaseUrl =
    'https://hmis-authapi.pshealthpunjab.gov.pk';

/// True when `--dart-define=USE_LOCAL_API=true` (debug backends only).
bool get useLocalApi {
  const flag = String.fromEnvironment('USE_LOCAL_API', defaultValue: '');
  return flag == 'true' || flag == '1';
}

String _normalizeBaseUrl(String url) {
  var value = url.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

bool get _isAndroidEmulatorHost {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

String _localEmrBaseUrl() {
  if (kIsWeb) return 'https://localhost:7287';
  if (_isAndroidEmulatorHost) return 'https://10.0.2.2:7287';
  return 'https://localhost:7287';
}

String _localAuthServerBaseUrl() {
  if (kIsWeb) return 'http://localhost:5045';
  if (_isAndroidEmulatorHost) return 'http://10.0.2.2:5045';
  return 'http://localhost:5045';
}

/// Resolves the base URL for HMIS_Prod.
///
/// Priority:
/// 1. `--dart-define=EMR_BASE_URL=...`
/// 2. Release/profile → [productionEmrBaseUrl]
/// 3. Debug + `USE_LOCAL_API=true` → localhost / emulator loopback
/// 4. Debug default → [productionEmrBaseUrl]
String resolveEmrBaseUrl() {
  const defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty) return _normalizeBaseUrl(defined);

  if (!kDebugMode) return productionEmrBaseUrl;
  if (useLocalApi) return _localEmrBaseUrl();
  return productionEmrBaseUrl;
}

/// Resolves the base URL for HMIS_AuthServer.
///
/// Priority mirrors [resolveEmrBaseUrl] with `AUTH_SERVER_BASE_URL` /
/// [productionAuthServerBaseUrl].
String resolveAuthServerBaseUrl() {
  const defined = String.fromEnvironment(
    'AUTH_SERVER_BASE_URL',
    defaultValue: '',
  );
  if (defined.isNotEmpty) return _normalizeBaseUrl(defined);

  if (!kDebugMode) return productionAuthServerBaseUrl;
  if (useLocalApi) return _localAuthServerBaseUrl();
  return productionAuthServerBaseUrl;
}

/// One-shot debug log of which backends the app will call.
void logResolvedApiEndpoints() {
  if (!kDebugMode) return;
  debugPrint(
    '[api_config] EMR=${resolveEmrBaseUrl()} '
    'AUTH=${resolveAuthServerBaseUrl()} '
    'localApi=$useLocalApi',
  );
}
