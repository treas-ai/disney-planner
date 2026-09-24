import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';

void main() {
  test('planned DPA facility ids survive JSON round trip as pre-trip intent', () {
    final settings = TripSettings.initial().copyWith(
      plannedDpaFacilityIds: const <String>['tdl_beauty_and_beast'],
    );
    final restored = TripSettings.fromJson(settings.toJson());
    expect(restored.plannedDpaFacilityIds, const <String>['tdl_beauty_and_beast']);
  });

  test('planned DPA defaults to empty for older saved settings', () {
    final json = TripSettings.initial().toJson()..remove('plannedDpaFacilityIds');
    final restored = TripSettings.fromJson(json);
    expect(restored.plannedDpaFacilityIds, isEmpty);
  });
}
