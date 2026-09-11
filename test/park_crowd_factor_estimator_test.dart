import 'package:disney_planner/domain/entities/crowd_factor_profile.dart';
import 'package:disney_planner/domain/enums/crowd_factor_confidence.dart';
import 'package:disney_planner/domain/services/park_crowd_factor_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

CrowdFactorProfile _factor(double value, String dimension) {
  return CrowdFactorProfile(
    parkId: 'tokyo_disneyland',
    facilityId: 'facility_$value',
    factor: value,
    source: 'test',
    calculatedAt: DateTime.utc(2026, 9, 10),
    sampleStart: DateTime.utc(2026, 9, 1),
    sampleEnd: DateTime.utc(2026, 9, 10),
    sampleCount: 100,
    excludedCount: 0,
    confidence: CrowdFactorConfidence.high,
    methodVersion: 'test',
    dimensions: [dimension],
  );
}

void main() {
  test('混雑係数は対象曜日・季節の上位四分位を安全側に使う', () {
    final result = const ParkCrowdFactorEstimator().estimate(
      factors: [
        _factor(1.0, 'weekday:6'),
        _factor(1.2, 'weekday:6'),
        _factor(1.5, 'weekday:6'),
        _factor(1.6, 'weekday:6'),
        _factor(1.1, 'season:autumn'),
      ],
      targetDate: DateTime(2026, 10, 3),
    );

    expect(result, 1.5);
  });

  test('低い代理係数でも基準値を下回らせない', () {
    final result = const ParkCrowdFactorEstimator().estimate(
      factors: [
        _factor(0.7, 'weekday:1'),
        _factor(0.8, 'season:autumn'),
      ],
      targetDate: DateTime(2026, 10, 5),
    );

    expect(result, 1.0);
  });
}
