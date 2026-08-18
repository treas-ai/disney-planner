import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../enums/priority_level.dart';
import 'facility_proximity_service.dart';

/// 目的地へ向かう途中で、小さな寄り道で回収できるWish候補を抽出する。
/// 固定予定との最終的な時間整合性はScheduleEngine側で判定する。
class RoutePickupService {
  const RoutePickupService({
    this.proximityService = const FacilityProximityService(),
  });

  final FacilityProximityService proximityService;

  List<Facility> candidates({
    required Facility from,
    required Facility destination,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    int maxDetourMinutes = 5,
  }) {
    final directMinutes = proximityService.estimatedWalkingMinutes(
      from,
      destination,
    );

    final result = facilities.where((facility) {
      if (facility.id == from.id || facility.id == destination.id) return false;
      final preference = _preferenceFor(facility.id, preferences);
      if (preference?.isExcluded == true) return false;
      if (!_isWanted(preference, facility)) return false;

      final viaMinutes = proximityService.estimatedWalkingMinutes(from, facility) +
          proximityService.estimatedWalkingMinutes(facility, destination);
      return viaMinutes - directMinutes <= maxDetourMinutes;
    }).toList(growable: false);

    result.sort((a, b) {
      final aDetour = _detour(from, destination, a, directMinutes);
      final bDetour = _detour(from, destination, b, directMinutes);
      final detourCompare = aDetour.compareTo(bDetour);
      if (detourCompare != 0) return detourCompare;
      final aPriority = _preferenceFor(a.id, preferences)?.priority.value ?? a.priority.value;
      final bPriority = _preferenceFor(b.id, preferences)?.priority.value ?? b.priority.value;
      return bPriority.compareTo(aPriority);
    });
    return List.unmodifiable(result);
  }

  int _detour(Facility from, Facility destination, Facility via, int direct) {
    return proximityService.estimatedWalkingMinutes(from, via) +
        proximityService.estimatedWalkingMinutes(via, destination) - direct;
  }

  bool _isWanted(PlanPreference? preference, Facility facility) {
    if (preference != null) return preference.priority != PriorityLevel.low;
    return facility.priority.value >= PriorityLevel.medium.value;
  }

  PlanPreference? _preferenceFor(String facilityId, List<PlanPreference> preferences) {
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) return preference;
    }
    return null;
  }
}
