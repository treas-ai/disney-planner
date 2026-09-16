import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _restaurant({
  bool requiresReservation = false,
  bool reservationRequired = false,
  bool supportsPrioritySeating = false,
}) {
  return Facility(
    id: 'restaurant',
    parkId: 'tokyo_disneyland',
    areaId: 'area',
    name: 'restaurant',
    category: FacilityCategory.restaurant,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    requiresReservation: requiresReservation,
    reservationRequired: reservationRequired,
    supportsPrioritySeating: supportsPrioritySeating,
  );
}

void main() {
  test('plain counter-service restaurant does not support reservation access', () {
    expect(_restaurant().supportsReservationAccess, isFalse);
  });

  test('master-data reservation capabilities enable reservation access', () {
    expect(
      _restaurant(requiresReservation: true).supportsReservationAccess,
      isTrue,
    );
    expect(
      _restaurant(reservationRequired: true).supportsReservationAccess,
      isTrue,
    );
    expect(
      _restaurant(supportsPrioritySeating: true).supportsReservationAccess,
      isTrue,
    );
  });
}
