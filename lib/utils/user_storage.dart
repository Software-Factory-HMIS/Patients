import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const String _userDataKey = 'registered_user_data';
  static const String _phoneKey = 'last_phone_number';
  static const String _themeModeKey = 'app_theme_mode';
  static const String _localeKey = 'app_locale';

  // Save registered user data (for self registration only)
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert DateTime to ISO string for storage
      final dataToSave = Map<String, dynamic>.from(userData);
      if (dataToSave['dateOfBirth'] != null && dataToSave['dateOfBirth'] is DateTime) {
        dataToSave['dateOfBirth'] = (dataToSave['dateOfBirth'] as DateTime).toIso8601String();
      }
      
      // Save user data as JSON string
      await prefs.setString(_userDataKey, json.encode(dataToSave));
      
      // Also save phone number separately for quick access
      if (userData['phone'] != null) {
        await prefs.setString(_phoneKey, userData['phone'] as String);
      }
      
    } catch (e) {
    }
  }

  // Get saved user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString == null) {
        return null;
      }
      
      final userData = json.decode(userDataString) as Map<String, dynamic>;
      
      // Convert ISO string back to DateTime
      if (userData['dateOfBirth'] != null && userData['dateOfBirth'] is String) {
        userData['dateOfBirth'] = DateTime.parse(userData['dateOfBirth'] as String);
      }
      
      return userData;
    } catch (e) {
      return null;
    }
  }

  // Get saved phone number
  static Future<String?> getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey);
    } catch (e) {
      return null;
    }
  }

  // Clear saved user data
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.remove(_phoneKey);
    } catch (e) {
    }
  }

  // Check if user data exists
  static Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userDataKey);
    } catch (e) {
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
      return existing.map(int.tryParse).whereType<int>().where((id) => id > 0).toList();
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

