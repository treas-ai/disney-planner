import 'dart:math' as math;

import '../entities/facility.dart';
import '../enums/proximity_level.dart';

/// 施設間の「近さ」を、エリア名だけでなく座標から評価する。
///
/// マスターデータの座標は施設中心点のため、directExit は極めて近い施設を
/// 表す近似値として扱う。将来、出口座標データが追加された場合もこのAPIを
/// 維持したまま差し替えられる。
class FacilityProximityService {
  const FacilityProximityService();

  double distanceMeters(Facility from, Facility to) {
    const earthRadiusMeters = 6371000.0;
    final lat1 = _radians(from.coordinate.latitude);
    final lat2 = _radians(to.coordinate.latitude);
    final deltaLat = _radians(
      to.coordinate.latitude - from.coordinate.latitude,
    );
    final deltaLon = _radians(
      to.coordinate.longitude - from.coordinate.longitude,
    );

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  ProximityLevel level(Facility from, Facility to) {
    final meters = distanceMeters(from, to);
    if (meters <= 45) return ProximityLevel.directExit;
    if (meters <= 150) return ProximityLevel.veryNear;
    if (meters <= 300) return ProximityLevel.near;
    if (from.areaId == to.areaId) return ProximityLevel.sameArea;
    return ProximityLevel.far;
  }

  int estimatedWalkingMinutes(Facility from, Facility to) {
    final meters = distanceMeters(from, to);
    if (meters <= 45) return 1;
    // パーク内は混雑・迂回を考慮し約65m/分で概算。最低1分。
    return math.max(1, (meters / 65).ceil());
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
