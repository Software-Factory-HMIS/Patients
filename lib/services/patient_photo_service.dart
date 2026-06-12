import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local profile photo storage keyed by patient ID.
class PatientPhotoService {
  PatientPhotoService._();
  static final PatientPhotoService instance = PatientPhotoService._();

  final ValueNotifier<int> revision = ValueNotifier(0);
  final ImagePicker _picker = ImagePicker();

  static String _pathKey(int patientId) => 'patient_profile_photo_path_$patientId';
  static String _bytesKey(int patientId) => 'patient_profile_photo_b64_$patientId';

  Future<PatientPhotoData?> load(int patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey(patientId));
    if (!kIsWeb && path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        return PatientPhotoData(filePath: path);
      }
    }

    final encoded = prefs.getString(_bytesKey(patientId));
    if (encoded != null && encoded.isNotEmpty) {
      try {
        return PatientPhotoData(bytes: base64Decode(encoded));
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Future<bool> pickAndSave(int patientId) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (file == null) return false;

    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await prefs.setString(_bytesKey(patientId), base64Encode(bytes));
      await prefs.remove(_pathKey(patientId));
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final dot = file.path.lastIndexOf('.');
      final safeExt = dot >= 0 ? file.path.substring(dot) : '.jpg';
      final destPath = '${dir.path}/patient_photo_$patientId$safeExt';
      await File(destPath).writeAsBytes(await file.readAsBytes());
      await prefs.setString(_pathKey(patientId), destPath);
      await prefs.remove(_bytesKey(patientId));
    }

    revision.value++;
    return true;
  }

  Future<void> remove(int patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey(patientId));
    if (!kIsWeb && path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await prefs.remove(_pathKey(patientId));
    await prefs.remove(_bytesKey(patientId));
    revision.value++;
  }
}

class PatientPhotoData {
  final String? filePath;
  final Uint8List? bytes;

  const PatientPhotoData({this.filePath, this.bytes});
}
