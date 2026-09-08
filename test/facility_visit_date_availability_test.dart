import 'package:flutter_test/flutter_test.dart';

import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/facility_operating_status.dart';
import 'package:disney_planner/domain/enums/park_status.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';

Facility _facility({
  DateTime? availableStart,
  DateTime? availableEnd,
  FacilityOperatingStatus operatingStatus = FacilityOperatingStatus.operating,
  DateTime? closureStart,
  DateTime? closureEnd,
  bool isOperating = true,
}) {
  return Facility(
    id: 'f',
    parkId: 'tokyo_disneyland',
    areaId: 'area',
    name: 'test',
    category: FacilityCategory.attraction,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    status: ParkStatus.open,
    isOperating: isOperating,
    operatingStatus: operatingStatus,
    availableStartDate: availableStart,
    availableEndDate: availableEnd,
    closureStartDate: closureStart,
    closureEndDate: closureEnd,
  );
}

void main() {
  test('seasonal facility is selectable only inside official availability', () {
    final facility = _facility(
      availableStart: DateTime(2026, 9, 16),
      availableEnd: DateTime(2026, 10, 31),
    );
    expect(facility.canAddToPlanAt(DateTime(2026, 9, 15)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 9, 16)), isTrue);
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 31)), isTrue);
    expect(facility.canAddToPlanAt(DateTime(2026, 11, 1)), isFalse);
  });

  test('scheduled closure reopens after official end even if current flag is false', () {
    final facility = _facility(
      operatingStatus: FacilityOperatingStatus.scheduledClosure,
      closureStart: DateTime(2026, 1, 5),
      closureEnd: DateTime(2026, 10, 22),
      isOperating: false,
    );
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 22)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 23)), isTrue);
  });

  test('seasonal availability and one-day closure can coexist', () {
    final facility = _facility(
      availableStart: DateTime(2026, 9, 16),
      availableEnd: DateTime(2026, 10, 31),
      operatingStatus: FacilityOperatingStatus.scheduledClosure,
      closureStart: DateTime(2026, 10, 2),
      closureEnd: DateTime(2026, 10, 2),
    );
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 1)), isTrue);
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 2)), isFalse);
    expect(facility.canAddToPlanAt(DateTime(2026, 10, 3)), isTrue);
  });
}
