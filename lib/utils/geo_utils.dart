import 'dart:math' as math;

import 'package:x_amap_flutter_base/amap_flutter_base.dart';

/// Haversine distance in meters (adequate for short-range "distance from me").
double distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);
  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return earthRadius * c;
}

double _rad(double deg) => deg * math.pi / 180.0;
