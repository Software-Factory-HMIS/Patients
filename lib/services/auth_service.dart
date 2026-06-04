import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _patientDataKey = 'patient_data';
  static const String _refreshTokenExpiryKey = 'refresh_token_expiry';

  static final FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );

  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();

  AuthService._();

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  Map<String, dynamic>? _patientData;

  String get baseUrl => resolveEmrBaseUrl();

  Future<void> _migrateTokensFromSharedPreferencesIfNeeded() async {
    final existing = await _secure.read(key: _accessTokenKey);
    if (existing != null) return;

    final prefs = await SharedPreferences.getInstance();
    final oldAccess = prefs.getString(_accessTokenKey);
    final oldRefresh = prefs.getString(_refreshTokenKey);
    final oldExpiry = prefs.getString(_tokenExpiryKey);
    final oldRefreshExp = prefs.getString(_refreshTokenExpiryKey);

    if (oldAccess != null) await _secure.write(key: _accessTokenKey, value: oldAccess);
    if (oldRefresh != null) await _secure.write(key: _refreshTokenKey, value: oldRefresh);
    if (oldExpiry != null) await _secure.write(key: _tokenExpiryKey, value: oldExpiry);
    if (oldRefreshExp != null) await _secure.write(key: _refreshTokenExpiryKey, value: oldRefreshExp);

    if (oldAccess != null) await prefs.remove(_accessTokenKey);
    if (oldRefresh != null) await prefs.remove(_refreshTokenKey);
    if (oldExpiry != null) await prefs.remove(_tokenExpiryKey);
    if (oldRefreshExp != null) await prefs.remove(_refreshTokenExpiryKey);
  }

  Future<void> init() async {
    await _migrateTokensFromSharedPreferencesIfNeeded();

    _accessToken = await _secure.read(key: _accessTokenKey);
    _refreshToken = await _secure.read(key: _refreshTokenKey);

    final expiryStr = await _secure.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      _tokenExpiry = DateTime.tryParse(expiryStr);
    }

    final prefs = await SharedPreferences.getInstance();
    final patientDataStr = prefs.getString(_patientDataKey);
    if (patientDataStr != null) {
      _patientData = json.decode(patientDataStr) as Map<String, dynamic>;
    }
  }

  bool get isLoggedIn => _accessToken != null && _refreshToken != null;

  bool get isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 1)));
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
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<bool> login(String cnic, String password) async {
    try {
      final uri = Uri.parse('$baseUrl/api/patient-auth/login');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'cnic': cnic.replaceAll(RegExp(r'[^0-9]'), ''),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>?;

        if (data != null) {
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

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_patientDataKey, json.encode(_patientData));

          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final uri = Uri.parse('$baseUrl/api/patient-auth/refresh');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
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
      await _secure.write(key: _accessTokenKey, value: accessToken);
    }

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _secure.write(key: _refreshTokenKey, value: refreshToken);
    }

    _tokenExpiry = DateTime.now().add(Duration(minutes: tokenExpiryMinutes));
    await _secure.write(key: _tokenExpiryKey, value: _tokenExpiry!.toIso8601String());

    if (refreshTokenExpiry != null) {
      await _secure.write(key: _refreshTokenExpiryKey, value: refreshTokenExpiry);
    }
  }

  Future<void> logout() async {
    try {
      if (_accessToken != null) {
        final uri = Uri.parse('$baseUrl/api/patient-auth/logout');
        await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_accessToken',
              },
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

    await _secure.delete(key: _accessTokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await _secure.delete(key: _tokenExpiryKey);
    await _secure.delete(key: _refreshTokenExpiryKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_patientDataKey);
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_patientDataKey, json.encode(_patientData));
  }
}
