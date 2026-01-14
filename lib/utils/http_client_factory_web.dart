// Web implementation stub
import 'package:http/http.dart' as http;

/// Stub function for web - SSL bypass is not needed (browser handles it)
http.Client createHttpClientWithSslBypass(String url) {
  // On web, browser handles SSL validation
  return http.Client();
}
