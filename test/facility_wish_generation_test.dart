import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('facility categories used by Wish List stay available', () {
    const facility = Facility(
      id: 'attraction-1',
      parkId: 'tokyo_disneyland',
      areaId: 'area',
      name: 'テストアトラクション',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
    );

    expect(facility.category, FacilityCategory.attraction);
    expect(facility.isOpen, isTrue);
  });
}
