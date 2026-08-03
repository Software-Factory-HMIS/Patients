import 'package:http/http.dart' as http;

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.2');

Map<String, String> appVersionHeaders([Map<String, String>? headers]) => {
  ...?headers,
  'X-App-Version': appVersion,
};

class VersionedHttpClient extends http.BaseClient {
  VersionedHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['X-App-Version'] = appVersion;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
