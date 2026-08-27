import 'package:flutter_test/flutter_test.dart';

import 'package:disney_planner/domain/entities/facility_location.dart';

void main() {
  test('ordinary facility exits in its entry area when exit metadata is omitted', () {
    const location = FacilityLocation(
      parkId: 'park',
      facilityId: 'normal',
      areaId: 'area_a',
      x: 0,
      y: 0,
    );

    expect(location.effectiveExitAreaId, 'area_a');
    expect(location.changesGuestArea, isFalse);
    expect(location.hasAmbiguousExit, isFalse);
  });

  test('fixed-route transport can finish in a different area', () {
    const location = FacilityLocation(
      parkId: 'tokyo_disneysea',
      facilityId: 'tds_pd_a_003',
      areaId: 'tds_port_discovery',
      exitAreaId: 'tds_american_waterfront',
      x: 0,
      y: 0,
    );

    expect(location.effectiveExitAreaId, 'tds_american_waterfront');
    expect(location.changesGuestArea, isTrue);
  });

  test('variable-route transport never guesses an exit area', () {
    const location = FacilityLocation(
      parkId: 'tokyo_disneysea',
      facilityId: 'tds_lrd_a_003',
      areaId: 'tds_lost_river_delta',
      possibleExitAreaIds: [
        'tds_mediterranean_harbor',
        'tds_american_waterfront',
      ],
      x: 0,
      y: 0,
    );

    expect(location.hasAmbiguousExit, isTrue);
    expect(location.effectiveExitAreaId, 'tds_lost_river_delta');
    expect(location.changesGuestArea, isFalse);
  });

  test('possible exits survive JSON round-trip', () {
    const original = FacilityLocation(
      parkId: 'tokyo_disneysea',
      facilityId: 'tds_aw_a_006',
      areaId: 'tds_american_waterfront',
      possibleExitAreaIds: [
        'tds_lost_river_delta',
        'tds_american_waterfront',
      ],
      x: 0,
      y: 0,
    );

    final restored = FacilityLocation.fromJson(original.toJson());

    expect(restored.hasAmbiguousExit, isTrue);
    expect(
      restored.possibleExitAreaIds,
      ['tds_lost_river_delta', 'tds_american_waterfront'],
    );
  });
}
