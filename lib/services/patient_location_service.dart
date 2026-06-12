import 'package:geolocator/geolocator.dart';

class PatientLocationService {
  PatientLocationService._();

  static final instance = PatientLocationService._();

  /// Requests permission when needed and returns the current device position.
  Future<Position?> requestCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  /// Warm up location permission early in the app flow.
  Future<void> warmUp() async {
    try {
      await requestCurrentPosition();
    } catch (_) {}
  }
}
