import 'package:drift/drift.dart';
import 'package:drift/web.dart';

LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async => WebDatabase.withStorage(
        DriftWebStorage.indexedDb('patient_history'),
      ));
}
