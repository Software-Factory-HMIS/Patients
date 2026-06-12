import '../models/appointment_models.dart';
import '../utils/emr_api_client.dart';
import '../utils/geo_utils.dart';

class NearestHospitalResult {
  final Hospital hospital;
  final double distanceKm;
  final bool usedApproximateLocation;

  const NearestHospitalResult({
    required this.hospital,
    required this.distanceKm,
    this.usedApproximateLocation = false,
  });
}

class NearbyHospitalsResponse {
  final double? latitude;
  final double? longitude;
  final List<NearestHospitalResult> results;

  const NearbyHospitalsResponse({
    required this.results,
    this.latitude,
    this.longitude,
  });
}

class NearestHospitalService {
  final EmrApiClient _api;

  NearestHospitalService({EmrApiClient? api}) : _api = api ?? EmrApiClient();

  Future<List<NearestHospitalResult>> findNearestHospitals({
    required double latitude,
    required double longitude,
    int limit = 5,
  }) async {
    final hospitalsData = await _api.searchHospitals('', limit: 200);
    final hospitals = hospitalsData
        .map((json) => Hospital.fromJson(json as Map<String, dynamic>))
        .where((h) => h.isActive && h.hospitalID > 0 && h.name.isNotEmpty)
        .toList();

    final ranked = <NearestHospitalResult>[];

    for (final hospital in hospitals) {
      final coords = hospital.resolvedCoordinates;
      if (coords == null) continue;

      ranked.add(
        NearestHospitalResult(
          hospital: hospital,
          distanceKm: haversineDistanceKm(
            latitude,
            longitude,
            coords.$1,
            coords.$2,
          ),
          usedApproximateLocation: !hospital.hasCoordinates,
        ),
      );
    }

    ranked.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    if (ranked.length <= limit) return ranked;
    return ranked.sublist(0, limit);
  }

  Future<NearestHospitalResult?> findNearest({
    required double latitude,
    required double longitude,
  }) async {
    final results = await findNearestHospitals(
      latitude: latitude,
      longitude: longitude,
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }
}
