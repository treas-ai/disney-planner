import 'package:disney_planner/domain/entities/crowd_factor_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/crowd_factor_confidence.dart';
import 'package:disney_planner/domain/services/crowd_factor_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('combined result remains in five-minute units', () {
    const calculator = CrowdFactorCalculator();
    final result = calculator.apply(
      baseline: const WaitTimeRange(
        minMinutes: 31,
        typicalMinutes: 47,
        maxMinutes: 68,
      ),
      factors: [
        CrowdFactorProfile(
          parkId: 'park',
          facilityId: 'facility',
          factor: 1.2,
          source: 'test',
          calculatedAt: DateTime(2026, 8, 5),
          sampleStart: DateTime(2024),
          sampleEnd: DateTime(2026),
          sampleCount: 100,
          excludedCount: 5,
          confidence: CrowdFactorConfidence.high,
          methodVersion: '1.0',
          dimensions: const ['saturday'],
        ),
      ],
    );

    expect(result.minMinutes % 5, 0);
    expect(result.typicalMinutes % 5, 0);
    expect(result.maxMinutes % 5, 0);
  });
}
