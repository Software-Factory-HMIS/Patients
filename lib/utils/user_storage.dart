import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const String _userDataKey = 'registered_user_data';
  static const String _phoneKey = 'last_phone_number';

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

  // Save recent appointments
  static Future<void> saveRecentAppointments(List<Map<String, dynamic>> appointments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recent_appointments', json.encode(appointments));
    } catch (e) {
    }
  }

  // Get saved recent appointments
  static Future<List<Map<String, dynamic>>?> getRecentAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appointmentsString = prefs.getString('recent_appointments');
      
      if (appointmentsString == null) {
        return null;
      }
      
      final appointmentsList = json.decode(appointmentsString) as List;
      return appointmentsList.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return null;
    }
  }
}

