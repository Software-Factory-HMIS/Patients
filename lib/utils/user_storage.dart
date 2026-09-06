import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_secure_storage.dart';

class UserStorage {
  static const String _userDataKey = 'registered_user_data';
  static const String _phoneKey = 'last_phone_number';
  static const String _themeModeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale';

  static Future<String?> _readSensitive(String key) async {
    final secureValue = await appSecureStorage.read(key: key);
    final prefs = await SharedPreferences.getInstance();
    final oldValue = prefs.getString(key);
    if (secureValue == null && oldValue != null) {
      await appSecureStorage.write(key: key, value: oldValue);
    }
    await prefs.remove(key);
    return secureValue ?? oldValue;
  }

  // Persist signed-in patient profile (key name kept for existing installs)
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      // Convert DateTime to ISO string for storage
      final dataToSave = Map<String, dynamic>.from(userData);
      if (dataToSave['dateOfBirth'] != null &&
          dataToSave['dateOfBirth'] is DateTime) {
        dataToSave['dateOfBirth'] = (dataToSave['dateOfBirth'] as DateTime)
            .toIso8601String();
      }

      await appSecureStorage.write(
        key: _userDataKey,
        value: json.encode(dataToSave),
      );

      // Also save phone number separately for quick access
      if (userData['phone'] != null) {
        await appSecureStorage.write(
          key: _phoneKey,
          value: userData['phone'].toString(),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.remove(_phoneKey);
    } catch (_) {}
  }

  // Get saved user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final userDataString = await _readSensitive(_userDataKey);

      if (userDataString == null) {
        return null;
      }

      final userData = json.decode(userDataString) as Map<String, dynamic>;

      // Convert ISO string back to DateTime
      if (userData['dateOfBirth'] != null &&
          userData['dateOfBirth'] is String) {
        userData['dateOfBirth'] = DateTime.parse(
          userData['dateOfBirth'] as String,
        );
      }

      return userData;
    } catch (e) {
      return null;
    }
  }

  // Get saved phone number
  static Future<String?> getPhoneNumber() async {
    try {
      return await _readSensitive(_phoneKey);
    } catch (e) {
      return null;
    }
  }

  // Clear saved user data
  static Future<void> clearUserData() async {
    try {
      await appSecureStorage.delete(key: _userDataKey);
      await appSecureStorage.delete(key: _phoneKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.remove(_phoneKey);
    } catch (_) {}
  }

  // Check if user data exists
  static Future<bool> hasUserData() async {
    try {
      return await _readSensitive(_userDataKey) != null;
    } catch (_) {
      return false;
    }
  }

  static const String _knownHospitalIdsKey = 'known_hospital_ids';

  /// Remember hospitals the patient has visited so live queue APIs can be queried.
  static Future<void> addKnownHospitalId(int hospitalId) async {
    if (hospitalId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_knownHospitalIdsKey) ?? [];
      final ids = {...existing.map(int.tryParse).whereType<int>(), hospitalId};
      await prefs.setStringList(
        _knownHospitalIdsKey,
        ids.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }

  static Future<List<int>> getKnownHospitalIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_knownHospitalIdsKey) ?? [];
      return existing
          .map(int.tryParse)
          .whereType<int>()
          .where((id) => id > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveThemeMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode);
    } catch (e) {
      // ignore
    }
  }

  static Future<String?> getThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_themeModeKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveLocale(String locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale);
    } catch (_) {}
  }

  static Future<String?> getLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_localeKey);
    } catch (_) {
      return null;
    }
  }
}
