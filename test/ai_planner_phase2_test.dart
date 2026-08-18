import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/services/facility_proximity_service.dart';
import 'package:disney_planner/domain/services/route_optimizer.dart';
import 'package:disney_planner/domain/services/route_pickup_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility facility(String id, double lat, double lon, {String area = 'a'}) {
  return Facility(
    id: id,
    parkId: 'tdl',
    areaId: area,
    name: id,
    category: FacilityCategory.attraction,
    coordinate: Coordinate(latitude: lat, longitude: lon),
    priority: PriorityLevel.high,
  );
}

void main() {
  const proximity = FacilityProximityService();

  test('nearby facilities are distinguished by coordinate distance', () {
    final from = facility('from', 35.630000, 139.880000);
    final almostExit = facility('exit', 35.630100, 139.880100);
    final farther = facility('farther', 35.632000, 139.882000);

    expect(proximity.distanceMeters(from, almostExit), lessThan(45));
    expect(
      proximity.distanceMeters(from, almostExit),
      lessThan(proximity.distanceMeters(from, farther)),
    );
  });

  test('route optimizer reduces local backtracking for equal-priority wishes', () {
    final a = facility('a', 35.6300, 139.8800);
    final far = facility('far', 35.6320, 139.8820);
    final near = facility('near', 35.6302, 139.8802);
    final middle = facility('middle', 35.6310, 139.8810);

    final result = const RouteOptimizer().optimize(
      facilities: [a, far, near, middle],
      preferences: const [],
    );

    expect(result.first.id, 'a');
    expect(result[1].id, 'near');
  });

  test('route pickup finds wanted facility with small detour', () {
    final from = facility('from', 35.6300, 139.8800);
    final destination = facility('destination', 35.6320, 139.8820);
    final pickup = facility('pickup', 35.6310, 139.8810);
    final excluded = facility('excluded', 35.6311, 139.8811);

    final preferences = [
      PlanPreference.initial(facilityId: 'pickup')
          .copyWith(priority: PriorityLevel.high),
      PlanPreference.initial(facilityId: 'excluded')
          .copyWith(priority: PriorityLevel.high, isExcluded: true),
    ];

    final result = const RoutePickupService().candidates(
      from: from,
      destination: destination,
      facilities: [pickup, excluded],
      preferences: preferences,
    );

    expect(result.map((item) => item.id), contains('pickup'));
    expect(result.map((item) => item.id), isNot(contains('excluded')));
  });
}
