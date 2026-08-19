import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_range.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/dynamic_wait_scoring_service.dart';

void main() {
  test('朝一以外の中央値との差を待ち時間節約として計算する', () {
    final profile = TimeBandWaitProfile(facilityId: 'popular', parkId: 'tokyo_disneyland', ranges: const {
      WaitTimeBand.afterOpening: WaitTimeRange(minMinutes: 20, typicalMinutes: 30, maxMinutes: 40),
      WaitTimeBand.beforeLunch: WaitTimeRange(minMinutes: 100, typicalMinutes: 120, maxMinutes: 140),
      WaitTimeBand.afterLunch: WaitTimeRange(minMinutes: 130, typicalMinutes: 150, maxMinutes: 170),
      WaitTimeBand.beforeDinner: WaitTimeRange(minMinutes: 110, typicalMinutes: 140, maxMinutes: 160),
    }, source: 'historical-db', calculatedAt: DateTime(2026, 8, 1), sampleCount: 120);
    final result = const DynamicWaitScoringService().evaluate(facilityId: 'popular', profiles: [profile]);
    expect(result.openingMinutes, 30); expect(result.normalMinutes, 140); expect(result.savingMinutes, 110); expect(result.confidence, WaitPredictionConfidence.high);
  });
  test('DBが無い場合は固定人気値を捏造せず節約0として扱う', () {
    final result = const DynamicWaitScoringService().evaluate(facilityId: 'unknown', profiles: const [], fallbackMinutes: 45);
    expect(result.openingMinutes, 45); expect(result.normalMinutes, 45); expect(result.savingMinutes, 0); expect(result.usedFallback, isTrue);
  });
}
