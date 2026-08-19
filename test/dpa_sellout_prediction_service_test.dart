import 'package:disney_planner/domain/entities/dpa_sellout_profile.dart';
import 'package:disney_planner/domain/services/dpa_sellout_prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = DpaSelloutPredictionService();
  final profile = DpaSelloutProfile(
    facilityId: 'ride',
    parkId: 'park',
    averageSelloutTime: '09:54',
    sampleCount: 31,
    source: 'seed',
    checkedAt: DateTime(2026, 8, 19),
  );

  test('entry before average sellout returns remaining minutes', () {
    final result = service.evaluate(
      facilityId: 'ride',
      predictedEntryMinuteOfDay: 9 * 60,
      profiles: [profile],
    );
    expect(result.minutesUntilAverageSellout, 54);
    expect(result.risk, DpaSelloutRisk.medium);
  });

  test('entry after average sellout is likely sold out', () {
    final result = service.evaluate(
      facilityId: 'ride',
      predictedEntryMinuteOfDay: 10 * 60,
      profiles: [profile],
    );
    expect(result.risk, DpaSelloutRisk.likelySoldOut);
  });

  test('unknown facility never invents sellout time', () {
    final result = service.evaluate(
      facilityId: 'unknown',
      predictedEntryMinuteOfDay: 9 * 60,
      profiles: [profile],
    );
    expect(result.risk, DpaSelloutRisk.unknown);
    expect(result.minutesUntilAverageSellout, isNull);
  });
}
