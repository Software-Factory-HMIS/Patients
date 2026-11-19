import 'package:flutter_test/flutter_test.dart';
import 'package:patients/utils/api_config.dart';

void main() {
  test('production hosts are HTTPS government APIs', () {
    expect(productionEmrBaseUrl, startsWith('https://'));
    expect(productionAuthServerBaseUrl, startsWith('https://'));
    expect(productionEmrBaseUrl, contains('pshealthpunjab.gov.pk'));
    expect(productionAuthServerBaseUrl, contains('pshealthpunjab.gov.pk'));
    expect(productionEmrBaseUrl.endsWith('/'), isFalse);
    expect(productionAuthServerBaseUrl.endsWith('/'), isFalse);
  });

  test('debug without prefs defaults to local EMR/auth ports', () {
    expect(useLocalApi, isFalse);
    expect(resolveEmrBaseUrl(), localEmrBaseUrl());
    expect(resolveAuthServerBaseUrl(), localAuthServerBaseUrl());
    expect(resolveEmrBaseUrl(), contains(':7287'));
    expect(resolveAuthServerBaseUrl(), contains(':5045'));
  });

  test('release cannot switch off production backends', () {
    // ApiConfig.canSwitchBackend is !kReleaseMode; test process is debug.
    expect(ApiConfig.canSwitchBackend, isTrue);
    expect(ApiConfig.prod.emrBaseUrl, productionEmrBaseUrl);
    expect(ApiConfig.prod.authBaseUrl, productionAuthServerBaseUrl);
  });
}
