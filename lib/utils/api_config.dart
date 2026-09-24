import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String productionEmrBaseUrl = 'https://hmis-api.pshealthpunjab.gov.pk';
const String productionAuthServerBaseUrl =
    'https://hmis-authapi.pshealthpunjab.gov.pk';
const String betaEmrBaseUrl = 'https://beta-hmis-api.pshealthpunjab.gov.pk';
const String betaAuthServerBaseUrl =
    'https://beta-hmis-authapi.pshealthpunjab.gov.pk';

bool get useLocalApi {
  const flag = String.fromEnvironment('USE_LOCAL_API', defaultValue: '');
  return flag == 'true' || flag == '1';
}

String normalizeBaseUrl(String url) {
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

String localEmrBaseUrl() {
  if (kIsWeb) return 'https://localhost:7287';
  if (_isAndroidEmulatorHost) return 'https://10.0.2.2:7287';
  return 'https://localhost:7287';
}

String localAuthServerBaseUrl() {
  if (kIsWeb) return 'http://localhost:5045';
  if (_isAndroidEmulatorHost) return 'http://10.0.2.2:5045';
  return 'http://localhost:5045';
}

class BackendPair {
  const BackendPair({
    required this.id,
    required this.label,
    required this.emrBaseUrl,
    required this.authBaseUrl,
    this.isCustom = false,
  });

  final String id;
  final String label;
  final String emrBaseUrl;
  final String authBaseUrl;
  final bool isCustom;
}

class ApiConfig {
  static const _prefsId = 'patient_api_server_id';
  static const _prefsCustomEmr = 'patient_api_custom_emr';
  static const _prefsCustomAuth = 'patient_api_custom_auth';

  static const prod = BackendPair(
    id: 'prod',
    label: 'Production',
    emrBaseUrl: productionEmrBaseUrl,
    authBaseUrl: productionAuthServerBaseUrl,
  );

  static const beta = BackendPair(
    id: 'beta',
    label: 'Beta',
    emrBaseUrl: betaEmrBaseUrl,
    authBaseUrl: betaAuthServerBaseUrl,
  );

  static BackendPair get local => BackendPair(
        id: 'local',
        label: 'Local',
        emrBaseUrl: localEmrBaseUrl(),
        authBaseUrl: localAuthServerBaseUrl(),
      );

  static const custom = BackendPair(
    id: 'custom',
    label: 'Custom',
    emrBaseUrl: '',
    authBaseUrl: '',
    isCustom: true,
  );

  static final unlockedNotifier = ValueNotifier<bool>(false);
  static final selectedIdNotifier = ValueNotifier<String>(prod.id);

  static String _customEmr = '';
  static String _customAuth = '';
  static bool _loaded = false;

  static String get customEmr => _customEmr;
  static String get customAuth => _customAuth;

  static bool get canSwitchBackend => !kReleaseMode;

  static List<BackendPair> get servers {
    if (!canSwitchBackend) return const [prod];
    return [prod, beta, local, custom];
  }

  static bool get hasMultipleServers => servers.length > 1;

  static BackendPair get selected {
    final id = selectedIdNotifier.value;
    for (final s in servers) {
      if (s.id == id) return s;
    }
    return prod;
  }

  static BackendPair get activePair {
    final s = selected;
    if (s.isCustom) {
      return BackendPair(
        id: custom.id,
        label: custom.label,
        emrBaseUrl: _customEmr.isEmpty ? productionEmrBaseUrl : _customEmr,
        authBaseUrl:
            _customAuth.isEmpty ? productionAuthServerBaseUrl : _customAuth,
        isCustom: true,
      );
    }
    return s;
  }

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    if (!canSwitchBackend) {
      selectedIdNotifier.value = prod.id;
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _customEmr = normalizeBaseUrl(prefs.getString(_prefsCustomEmr) ?? '');
      _customAuth = normalizeBaseUrl(prefs.getString(_prefsCustomAuth) ?? '');
      final saved = prefs.getString(_prefsId);
      if (saved != null && servers.any((s) => s.id == saved)) {
        selectedIdNotifier.value = saved;
      } else if (useLocalApi) {
        selectedIdNotifier.value = local.id;
      }
    } catch (_) {}
  }

  static Future<void> select(String id) async {
    if (!canSwitchBackend) return;
    if (!servers.any((s) => s.id == id)) return;
    selectedIdNotifier.value = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsId, id);
    } catch (_) {}
  }

  static Future<void> saveCustom({
    required String emr,
    required String auth,
  }) async {
    _customEmr = normalizeBaseUrl(emr);
    _customAuth = normalizeBaseUrl(auth);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCustomEmr, _customEmr);
      await prefs.setString(_prefsCustomAuth, _customAuth);
    } catch (_) {}
  }

  static void unlock() {
    if (canSwitchBackend) unlockedNotifier.value = true;
  }
}

String resolveEmrBaseUrl() {
  const defined = String.fromEnvironment('EMR_BASE_URL', defaultValue: '');
  if (defined.isNotEmpty && !ApiConfig.canSwitchBackend) {
    return normalizeBaseUrl(defined);
  }
  if (ApiConfig._loaded && ApiConfig.canSwitchBackend) {
    return normalizeBaseUrl(ApiConfig.activePair.emrBaseUrl);
  }
  if (defined.isNotEmpty) return normalizeBaseUrl(defined);
  if (!kDebugMode) return productionEmrBaseUrl;
  if (useLocalApi) return localEmrBaseUrl();
  return productionEmrBaseUrl;
}

String resolveAuthServerBaseUrl() {
  const defined = String.fromEnvironment(
    'AUTH_SERVER_BASE_URL',
    defaultValue: '',
  );
  if (defined.isNotEmpty && !ApiConfig.canSwitchBackend) {
    return normalizeBaseUrl(defined);
  }
  if (ApiConfig._loaded && ApiConfig.canSwitchBackend) {
    return normalizeBaseUrl(ApiConfig.activePair.authBaseUrl);
  }
  if (defined.isNotEmpty) return normalizeBaseUrl(defined);
  if (!kDebugMode) return productionAuthServerBaseUrl;
  if (useLocalApi) return localAuthServerBaseUrl();
  return productionAuthServerBaseUrl;
}

void logResolvedApiEndpoints() {
  if (!kDebugMode) return;
  debugPrint(
    '[api_config] EMR=${resolveEmrBaseUrl()} '
    'AUTH=${resolveAuthServerBaseUrl()} '
    'server=${ApiConfig.selected.id}',
  );
}
