import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/services/entry_prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = EntryPredictionService();

  test('general entry reserves post-entry time when Priority Pass is enabled', () {
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      queueArrivalTimeHour: 7,
      queueArrivalTimeMinute: 0,
      hasHappyEntry: false,
      canUseDpa: false,
      attractionDpaMaxUses: 0,
      canUsePriorityPass: true,
    );

    final result = service.predict(settings);

    expect(result.expectedEntryMinutes, 9 * 60 + 10);
    expect(result.postEntryOperationMinutes, 5);
    expect(result.firstFacilityArrivalMinutes, 9 * 60 + 20);
  });

  test('general entry has no artificial booking delay when app passes are off', () {
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      queueArrivalTimeHour: 7,
      queueArrivalTimeMinute: 0,
      hasHappyEntry: false,
      canUseDpa: false,
      attractionDpaMaxUses: 0,
      canUsePriorityPass: false,
    );

    final result = service.predict(settings);

    expect(result.postEntryOperationMinutes, 0);
    expect(result.firstFacilityArrivalMinutes, 9 * 60 + 15);
  });

  test('legacy Priority Pass preference is retired on JSON restore', () {
    final settings = TripSettings.initial().copyWith(canUsePriorityPass: true);
    final restored = TripSettings.fromJson(settings.toJson());

    expect(restored.canUsePriorityPass, isFalse);
  });
}
