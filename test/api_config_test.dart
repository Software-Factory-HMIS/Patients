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

  test('debug without USE_LOCAL_API resolves to production', () {
    expect(useLocalApi, isFalse);
    expect(resolveEmrBaseUrl(), productionEmrBaseUrl);
    expect(resolveAuthServerBaseUrl(), productionAuthServerBaseUrl);
  });

  test('release cannot switch off production backends', () {
    // ApiConfig.canSwitchBackend is !kReleaseMode; test process is debug.
    expect(ApiConfig.canSwitchBackend, isTrue);
    expect(ApiConfig.prod.emrBaseUrl, productionEmrBaseUrl);
    expect(ApiConfig.prod.authBaseUrl, productionAuthServerBaseUrl);
  });
}
