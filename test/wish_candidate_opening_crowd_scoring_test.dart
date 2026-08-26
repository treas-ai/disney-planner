import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/wish_candidate_scoring_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility(String id) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'test_area',
    name: id,
    category: FacilityCategory.attraction,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 10,
  );
}

TimeBandWaitProfile _profile(
  String id, {
  required int opening,
  required int beforeLunch,
}) {
  return TimeBandWaitProfile(
    facilityId: id,
    parkId: 'tokyo_disneyland',
    ranges: {
      WaitTimeBand.afterOpening: WaitTimeRange(
        minMinutes: opening,
        typicalMinutes: opening,
        maxMinutes: opening,
        sampleCount: 20,
      ),
      WaitTimeBand.beforeLunch: WaitTimeRange(
        minMinutes: beforeLunch,
        typicalMinutes: beforeLunch,
        maxMinutes: beforeLunch,
        sampleCount: 20,
      ),
      WaitTimeBand.afterLunch: const WaitTimeRange(
        minMinutes: 40,
        typicalMinutes: 40,
        maxMinutes: 40,
        sampleCount: 20,
      ),
    },
    source: 'test history',
    calculatedAt: DateTime.utc(2026, 8, 26),
    sampleCount: 60,
  );
}

void main() {
  test('first move favors an opening window over joining an opening rush', () {
    final openingWindow = _facility('opening_window');
    final openingRush = _facility('opening_rush');

    final scored = const WishCandidateScoringEngine().score(
      facilities: [openingWindow, openingRush],
      preferences: [
        PlanPreference.initial(facilityId: openingWindow.id),
        PlanPreference.initial(facilityId: openingRush.id),
      ],
      waitProfiles: [
        _profile(openingWindow.id, opening: 20, beforeLunch: 60),
        _profile(openingRush.id, opening: 60, beforeLunch: 40),
      ],
      availableMinutes: 600,
    );

    final window = scored.firstWhere(
      (item) => item.facility.id == openingWindow.id,
    );
    final rush = scored.firstWhere(
      (item) => item.facility.id == openingRush.id,
    );

    expect(window.firstMoveScore!, greaterThan(rush.firstMoveScore!));
    expect(window.firstMoveReasons.join(' '), contains('朝の低待ち時間'));
    expect(rush.firstMoveReasons.join(' '), contains('開園直後の群集集中'));
  });
}
