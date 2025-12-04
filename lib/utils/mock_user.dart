import 'user_storage.dart';

/// Mock user data for testing the application flow
class MockUser {
  static const Map<String, dynamic> mockUserData = {
    'fullName': 'Ahmed Ali',
    'cnic': '35202-1234567-1',
    'phone': '03001234567',
    'email': 'ahmed.ali@example.com',
    'dateOfBirth': '1990-05-15T00:00:00.000Z', // ISO string format
    'gender': 'Male',
    'address': '123 Main Street, Lahore, Pakistan',
    'bloodGroup': 'O+',
  };

  /// Initialize mock user data for testing
  /// This saves the mock user data to local storage
  static Future<void> initializeMockUser() async {
    try {
      // Convert date string to DateTime
      final userData = Map<String, dynamic>.from(mockUserData);
      userData['dateOfBirth'] = DateTime.parse(mockUserData['dateOfBirth'] as String);
      
      await UserStorage.saveUserData(userData);
      print('✅ Mock user initialized successfully');
      print('   Name: ${mockUserData['fullName']}');
      print('   Phone: ${mockUserData['phone']}');
      print('   CNIC: ${mockUserData['cnic']}');
    } catch (e) {
      print('❌ Error initializing mock user: $e');
    }
  }

  /// Check if mock user should be used
  /// Returns true if no user data exists in storage
  static Future<bool> shouldUseMockUser() async {
    final hasUserData = await UserStorage.hasUserData();
    return !hasUserData;
  }
}

