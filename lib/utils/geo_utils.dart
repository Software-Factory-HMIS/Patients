import 'dart:math' as math;

/// Haversine distance in kilometres between two WGS84 coordinates.
double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * math.pi / 180.0;

/// Approximate district centroids in Punjab for hospitals without stored coordinates.
class PunjabGeoLookup {
  PunjabGeoLookup._();

  static const _centroids = <String, (double, double)>{
    'lahore': (31.5204, 74.3587),
    'rawalpindi': (33.5651, 73.0169),
    'faisalabad': (31.4504, 73.1350),
    'multan': (30.1575, 71.5249),
    'gujranwala': (32.1877, 74.1945),
    'sialkot': (32.4945, 74.5229),
    'bahawalpur': (29.3956, 71.6836),
    'sargodha': (32.0836, 72.6711),
    'sheikhupura': (31.7131, 73.9783),
    'jhang': (31.2682, 72.3181),
    'gujrat': (32.5742, 74.0754),
    'sahiwal': (30.6667, 73.1000),
    'okara': (30.8081, 73.4458),
    'kasur': (31.1156, 74.4464),
    'rahim yar khan': (28.4202, 70.2989),
    'dera ghazi khan': (30.0561, 70.6348),
    'muzaffargarh': (30.1575, 71.1994),
    'attock': (33.7667, 72.3667),
    'vehari': (30.0444, 72.3556),
    'mianwali': (32.5836, 71.5264),
    'bhakkar': (31.6333, 71.0667),
    'chiniot': (31.7200, 72.9789),
    'hafizabad': (32.0700, 73.6881),
    'khanewal': (30.3017, 71.9321),
    'lodhran': (29.5333, 71.6333),
    'narowal': (32.0997, 74.8740),
    'pakpattan': (30.3500, 73.4000),
    'rajanpur': (29.1042, 70.3297),
    'toba tek singh': (30.9713, 72.4827),
    'layyah': (30.9650, 70.9400),
    'bahawalnagar': (29.9983, 73.2527),
    'khushab': (32.2967, 72.3500),
    'mandi bahauddin': (32.5833, 73.4833),
    'nankana sahib': (31.4500, 73.7000),
  };

  static (double lat, double lon)? centroidFor({String? district, String? tehsil, String? division}) {
    for (final value in [tehsil, district, division]) {
      final key = _normalize(value);
      if (key == null) continue;
      final exact = _centroids[key];
      if (exact != null) return exact;
      for (final entry in _centroids.entries) {
        if (key.contains(entry.key) || entry.key.contains(key)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim().toLowerCase();
    return trimmed.isEmpty ? null : trimmed;
  }
}
