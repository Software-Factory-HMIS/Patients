import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_secure_storage.dart';

/// Local profile photo storage keyed by patient ID.
class PatientPhotoService {
  PatientPhotoService._();
  static final PatientPhotoService instance = PatientPhotoService._();

  final ValueNotifier<int> revision = ValueNotifier(0);
  final ImagePicker _picker = ImagePicker();

  static String _pathKey(int patientId) =>
      'patient_profile_photo_path_$patientId';
  static String _bytesKey(int patientId) =>
      'patient_profile_photo_b64_$patientId';

  Future<PatientPhotoData?> load(int patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final oldPath = prefs.getString(_pathKey(patientId));
    final oldBytes = prefs.getString(_bytesKey(patientId));
    if (oldPath != null &&
        await appSecureStorage.read(key: _pathKey(patientId)) == null) {
      await appSecureStorage.write(key: _pathKey(patientId), value: oldPath);
    }
    if (oldBytes != null &&
        await appSecureStorage.read(key: _bytesKey(patientId)) == null) {
      await appSecureStorage.write(key: _bytesKey(patientId), value: oldBytes);
    }
    await prefs.remove(_pathKey(patientId));
    await prefs.remove(_bytesKey(patientId));

    var path = await appSecureStorage.read(key: _pathKey(patientId)) ?? oldPath;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      var file = File(path);
      if (await file.exists()) {
        final temporaryDirectory = await getTemporaryDirectory();
        final temporaryPrefix =
            '${temporaryDirectory.path}${Platform.pathSeparator}';
        if (!path.startsWith(temporaryPrefix)) {
          final dot = path.lastIndexOf('.');
          final safeExt = dot >= 0 ? path.substring(dot) : '.jpg';
          final migratedPath =
              '${temporaryDirectory.path}/patient_photo_$patientId$safeExt';
          file = await file.copy(migratedPath);
          await File(path).delete();
          path = migratedPath;
          await appSecureStorage.write(key: _pathKey(patientId), value: path);
        }
        return PatientPhotoData(filePath: path);
      }
    }

    final encoded =
        await appSecureStorage.read(key: _bytesKey(patientId)) ?? oldBytes;
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

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await appSecureStorage.write(
        key: _bytesKey(patientId),
        value: base64Encode(bytes),
      );
      await appSecureStorage.delete(key: _pathKey(patientId));
    } else {
      // Cache-only storage prevents patient photos from entering device backups.
      final dir = await getTemporaryDirectory();
      final dot = file.path.lastIndexOf('.');
      final safeExt = dot >= 0 ? file.path.substring(dot) : '.jpg';
      final destPath = '${dir.path}/patient_photo_$patientId$safeExt';
      await File(destPath).writeAsBytes(await file.readAsBytes());
      await appSecureStorage.write(key: _pathKey(patientId), value: destPath);
      await appSecureStorage.delete(key: _bytesKey(patientId));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey(patientId));
    await prefs.remove(_bytesKey(patientId));

    revision.value++;
    return true;
  }

  Future<void> remove(int patientId) async {
    final prefs = await SharedPreferences.getInstance();
    final path =
        await appSecureStorage.read(key: _pathKey(patientId)) ??
        prefs.getString(_pathKey(patientId));
    if (!kIsWeb && path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await prefs.remove(_pathKey(patientId));
    await prefs.remove(_bytesKey(patientId));
    await appSecureStorage.delete(key: _pathKey(patientId));
    await appSecureStorage.delete(key: _bytesKey(patientId));
    revision.value++;
  }
}

class PatientPhotoData {
  final String? filePath;
  final Uint8List? bytes;

  const PatientPhotoData({this.filePath, this.bytes});
}
