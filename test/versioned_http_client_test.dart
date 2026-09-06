import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:patients/utils/versioned_http_client.dart';

void main() {
  test('adds the configured app version without dropping headers', () async {
    final inner = MockClient((request) async {
      expect(request.headers['X-App-Version'], appVersion);
      expect(request.headers['Authorization'], 'Bearer token');
      return http.Response('{}', 200);
    });

    final response = await VersionedHttpClient(inner).get(
      Uri.parse('https://example.test/patient'),
      headers: const {'Authorization': 'Bearer token'},
    );

    expect(response.statusCode, 200);
    expect(appVersion, '1.0.2');
  });
}
