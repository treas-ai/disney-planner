import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/opening_crowd_behavior_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

TimeBandWaitProfile _profile({
  required String facilityId,
  required int opening,
  required int beforeLunch,
  int samples = 20,
}) {
  return TimeBandWaitProfile(
    facilityId: facilityId,
    parkId: 'tokyo_disneyland',
    ranges: {
      WaitTimeBand.afterOpening: WaitTimeRange(
        minMinutes: opening,
        typicalMinutes: opening,
        maxMinutes: opening,
        sampleCount: samples,
      ),
      WaitTimeBand.beforeLunch: WaitTimeRange(
        minMinutes: beforeLunch,
        typicalMinutes: beforeLunch,
        maxMinutes: beforeLunch,
        sampleCount: samples,
      ),
    },
    source: 'test history',
    calculatedAt: DateTime.utc(2026, 8, 26),
    sampleCount: samples * 2,
  );
}

void main() {
  const evaluator = OpeningCrowdBehaviorEvaluator();

  test('rewards an opening window that disappears toward late morning', () {
    final result = evaluator.evaluate(
      facilityId: 'far_attraction',
      parkId: 'tokyo_disneyland',
      profiles: [
        _profile(
          facilityId: 'far_attraction',
          opening: 20,
          beforeLunch: 60,
        ),
      ],
    );

    expect(result.usable, isTrue);
    expect(result.rawChangeMinutes, 40);
    expect(result.weightedValueMinutes, greaterThan(0));
    expect(result.reason, contains('朝の低待ち時間'));
  });

  test('penalizes joining an opening rush that eases later', () {
    final result = evaluator.evaluate(
      facilityId: 'headline',
      parkId: 'tokyo_disneyland',
      profiles: [
        _profile(
          facilityId: 'headline',
          opening: 90,
          beforeLunch: 70,
        ),
      ],
    );

    expect(result.usable, isTrue);
    expect(result.rawChangeMinutes, -20);
    expect(result.weightedValueMinutes, lessThan(0));
    expect(result.reason, contains('開園直後の群集集中'));
  });

  test('thin data stays neutral instead of changing first-move ordering', () {
    final result = evaluator.evaluate(
      facilityId: 'thin',
      parkId: 'tokyo_disneyland',
      profiles: [
        _profile(
          facilityId: 'thin',
          opening: 10,
          beforeLunch: 100,
          samples: 2,
        ),
      ],
    );

    expect(result.usable, isFalse);
    expect(result.weightedValueMinutes, 0);
  });
}
