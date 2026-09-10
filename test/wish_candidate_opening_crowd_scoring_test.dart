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

  test('unlimited ride removes standby-time urgency from first move', () {
    final target = _facility('unlimited_target');

    final normal = const WishCandidateScoringEngine().score(
      facilities: [target],
      preferences: [PlanPreference.initial(facilityId: 'unlimited_target')],
      waitProfiles: [
        _profile('unlimited_target', opening: 20, beforeLunch: 90),
      ],
      availableMinutes: 600,
    ).single;

    final unlimited = const WishCandidateScoringEngine().score(
      facilities: [target],
      preferences: [PlanPreference.initial(facilityId: 'unlimited_target')],
      waitProfiles: [
        _profile('unlimited_target', opening: 20, beforeLunch: 90),
      ],
      availableMinutes: 600,
      unlimitedRideBufferMinutes: {'unlimited_target': 20},
    ).single;

    expect(unlimited.predictedWaitMinutes, 20);
    expect(unlimited.firstMoveScore!, lessThan(normal.firstMoveScore!));
    expect(
      unlimited.firstMoveReasons.join(' '),
      contains('通常待ち時間による朝一緊急性は評価対象外'),
    );
    expect(
      unlimited.firstMoveReasons.join(' '),
      isNot(contains('朝一で約')),
    );
  });


  test('乗り放題プランでは対象外施設の通常待ち悪化を朝一価値として維持する', () {
    final covered = _facility('covered');
    final uncovered = _facility('uncovered');

    final scored = const WishCandidateScoringEngine().score(
      facilities: [covered, uncovered],
      preferences: [
        PlanPreference.initial(facilityId: 'covered'),
        PlanPreference.initial(facilityId: 'uncovered'),
      ],
      waitProfiles: [
        _profile('covered', opening: 20, beforeLunch: 90),
        _profile('uncovered', opening: 15, beforeLunch: 70),
      ],
      availableMinutes: 600,
      unlimitedRideBufferMinutes: {'covered': 20},
    );

    final coveredScore =
        scored.singleWhere((item) => item.facility.id == 'covered');
    final uncoveredScore =
        scored.singleWhere((item) => item.facility.id == 'uncovered');

    expect(
      uncoveredScore.firstMoveScore!,
      greaterThan(coveredScore.firstMoveScore!),
    );
  });


  test('乗り放題の高価値施設より待ち悪化する対象外施設を朝一で優先できる', () {
    final covered = _facility('covered_high_value');
    final uncovered = _facility('uncovered_scarce');

    final scored = const WishCandidateScoringEngine().score(
      facilities: [covered, uncovered],
      preferences: [
        PlanPreference.initial(facilityId: 'covered_high_value'),
        PlanPreference.initial(facilityId: 'uncovered_scarce'),
      ],
      waitProfiles: [
        _profile('covered_high_value', opening: 20, beforeLunch: 90),
        _profile('uncovered_scarce', opening: 15, beforeLunch: 60),
      ],
      availableMinutes: 600,
      unlimitedRideBufferMinutes: {'covered_high_value': 20},
    );

    final coveredScore = scored
        .singleWhere((item) => item.facility.id == 'covered_high_value');
    final uncoveredScore = scored
        .singleWhere((item) => item.facility.id == 'uncovered_scarce');

    expect(uncoveredScore.firstMoveScore!,
        greaterThan(coveredScore.firstMoveScore!));
  });

}
