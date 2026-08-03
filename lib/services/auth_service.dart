import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/app_secure_storage.dart';
import '../utils/versioned_http_client.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _patientDataKey = 'patient_data';
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry';

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _patientData;

  String get baseUrl => resolveEmrBaseUrl();

  Future<void> _migrateSensitivePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      _accessTokenKey,
      _refreshTokenKey,
      _tokenExpiryKey,
      _refreshTokenExpiryKey,
      _patientDataKey,
    ]) {
      final oldValue = prefs.getString(key);
      if (oldValue != null && await appSecureStorage.read(key: key) == null) {
        await appSecureStorage.write(key: key, value: oldValue);
      }
      await prefs.remove(key);
    }
  }

  Future<void> init() async {
    await _migrateSensitivePreferences();

    _accessToken = await appSecureStorage.read(key: _accessTokenKey);
    _refreshToken = await appSecureStorage.read(key: _refreshTokenKey);

    final expiryStr = await appSecureStorage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      _tokenExpiry = DateTime.tryParse(expiryStr);
    }

    final patientDataStr = await appSecureStorage.read(key: _patientDataKey);
    if (patientDataStr != null) {
      _patientData = json.decode(patientDataStr) as Map<String, dynamic>;
    }
  }

  bool get isLoggedIn => _accessToken != null && _refreshToken != null;

  bool get isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(
      _tokenExpiry!.subtract(const Duration(minutes: 1)),
    );
  }

  String? get accessToken => _accessToken;
  Map<String, dynamic>? get patientData => _patientData;

  Future<String?> getValidAccessToken() async {
    if (_accessToken == null) return null;

    if (isTokenExpired) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) return null;
    }

    return _accessToken;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getValidAccessToken();
    if (token == null) {
      return appVersionHeaders({'Content-Type': 'application/json'});
    }
    return appVersionHeaders({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final uri = Uri.parse('$baseUrl/api/patient-auth/refresh');
      final response = await http
          .post(
            uri,
            headers: appVersionHeaders({'Content-Type': 'application/json'}),
            body: json.encode({'refreshToken': _refreshToken}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;

        if (data != null) {
          await _saveTokens(
            accessToken: data['token'] as String?,
            refreshToken: data['refreshToken'] as String?,
            tokenExpiryMinutes: data['tokenExpiryMinutes'] as int? ?? 15,
          );
          return true;
        }
      }

      if (response.statusCode == 401) {
        await logout();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveTokens({
    String? accessToken,
    String? refreshToken,
    int tokenExpiryMinutes = 15,
    String? refreshTokenExpiry,
  }) async {
    if (accessToken != null) {
      _accessToken = accessToken;
      await appSecureStorage.write(key: _accessTokenKey, value: accessToken);
    }

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await appSecureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }

    _tokenExpiry = DateTime.now().add(Duration(minutes: tokenExpiryMinutes));
    await appSecureStorage.write(
      key: _tokenExpiryKey,
      value: _tokenExpiry!.toIso8601String(),
    );

    if (refreshTokenExpiry != null) {
      await appSecureStorage.write(
        key: _refreshTokenExpiryKey,
        value: refreshTokenExpiry,
      );
    }
  }

  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        final uri = Uri.parse('$baseUrl/api/patient-auth/logout');
        await http
            .post(
              uri,
              headers: appVersionHeaders({
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              }),
            )
            .timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      // ignore
    }

    await clearSession();
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    _patientData = null;

    await appSecureStorage.delete(key: _accessTokenKey);
    await appSecureStorage.delete(key: _refreshTokenKey);
    await appSecureStorage.delete(key: _tokenExpiryKey);
    await appSecureStorage.delete(key: _refreshTokenExpiryKey);
    await appSecureStorage.delete(key: _patientDataKey);

    final prefs = await SharedPreferences.getInstance();
    for (final key in const [
      _accessTokenKey,
      _refreshTokenKey,
      _tokenExpiryKey,
      _refreshTokenExpiryKey,
      _patientDataKey,
    ]) {
      await prefs.remove(key);
    }
  }

  Future<void> saveLoginResponse(Map<String, dynamic> data) async {
    await _saveTokens(
      accessToken: data['token'] as String?,
      refreshToken: data['refreshToken'] as String?,
      tokenExpiryMinutes: data['tokenExpiryMinutes'] as int? ?? 15,
      refreshTokenExpiry: data['refreshTokenExpiry'] as String?,
    );

    _patientData = {
      'patientID': data['patientID'],
      'mrn': data['mrn'],
      'fullName': data['fullName'],
      'cnic': data['cnic'],
      'dateOfBirth': data['dateOfBirth'],
      'gender': data['gender'],
      'contactNumber': data['contactNumber'],
      'email': data['email'],
      'address': data['address'],
      'bloodGroup': data['bloodGroup'],
    };

    await appSecureStorage.write(
      key: _patientDataKey,
      value: json.encode(_patientData),
    );
  }
}
