import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/live_pass_status.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/replanning_context.dart';
import 'package:disney_planner/domain/entities/weather_snapshot.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fatigue_level.dart';
import 'package:disney_planner/domain/enums/live_weather_condition.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/enums/replanning_action_type.dart';
import 'package:disney_planner/domain/services/realtime_replanning_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility facility(
  String id,
  double lat,
  double lon, {
  bool indoor = false,
  bool waterRide = false,
  int duration = 20,
  PriorityLevel priority = PriorityLevel.high,
}) {
  return Facility(
    id: id,
    parkId: 'tds',
    areaId: 'area',
    name: id,
    category: FacilityCategory.attraction,
    coordinate: Coordinate(latitude: lat, longitude: lon),
    isIndoor: indoor,
    isWaterRide: waterRide,
    durationMinutes: duration,
    priority: priority,
  );
}

void main() {
  const service = RealtimeReplanningService();

  test('long gap before fixed plan produces intermediate replanning suggestion', () {
    final context = ReplanningContext(
      now: DateTime(2026, 8, 13, 10, 15),
      nextFixedStartMinutes: 14 * 60,
      facilities: const [],
      preferences: const [],
    );

    final result = service.assess(context);
    final suggestion = result.firstWhere(
      (item) => item.type == ReplanningActionType.fillLongGap,
    );

    expect(suggestion.availableMinutes, 210);
  });

  test('heavy rain with fatigue and baggage proposes hotel break', () {
    final context = ReplanningContext(
      now: DateTime(2026, 8, 13, 16),
      facilities: const [],
      preferences: const [],
      weather: WeatherSnapshot(
        condition: LiveWeatherCondition.heavyRain,
        updatedAt: DateTime(2026, 8, 13, 16),
      ),
      fatigueLevel: FatigueLevel.high,
      hasBaggage: true,
      hotelBreakAvailable: true,
    );

    final types = service.assess(context).map((item) => item.type).toSet();
    expect(types, contains(ReplanningActionType.preferIndoor));
    expect(types, contains(ReplanningActionType.hotelBreak));
  });

  test('heavy rain prioritizes indoor at equal wish priority without deleting outdoor', () {
    final outdoor = facility('outdoor', 35.63, 139.88);
    final indoor = facility('indoor', 35.631, 139.881, indoor: true);
    final context = ReplanningContext(
      now: DateTime(2026, 8, 13, 11),
      facilities: [outdoor, indoor],
      preferences: const [],
      weather: WeatherSnapshot(
        condition: LiveWeatherCondition.heavyRain,
        updatedAt: DateTime(2026, 8, 13, 11),
      ),
    );

    final result = service.prioritizeForCurrentWeather(context);
    expect(result.first.id, 'indoor');
    expect(result.map((item) => item.id), contains('outdoor'));
  });

  test('unavailable DPA creates fallback suggestion instead of silently switching', () {
    final target = facility('show', 35.63, 139.88);
    final preference = PlanPreference.initial(facilityId: target.id).copyWith(
      useDpa: true,
      accessMethod: FacilityAccessMethod.dpa,
    );
    final context = ReplanningContext(
      now: DateTime(2026, 8, 12, 18),
      facilities: [target],
      preferences: [preference],
      passStatuses: [
        LivePassStatus(
          parkId: 'tdl',
          facilityId: target.id,
          type: LivePassType.dpa,
          availability: LivePassAvailability.unavailable,
          updatedAt: DateTime(2026, 8, 12, 18),
        ),
      ],
    );

    final result = service.assess(context);
    final fallback = result.firstWhere(
      (item) => item.type == ReplanningActionType.passFallback,
    );
    expect(fallback.facilityId, target.id);
    expect(fallback.reason, contains('自動変更せず'));
  });

  test('route pickup is suggested only when it fits before the fixed plan', () {
    final from = facility('from', 35.6300, 139.8800, duration: 10);
    final destination = facility('destination', 35.6320, 139.8820, duration: 20);
    final pickup = facility('pickup', 35.6310, 139.8810, duration: 15);
    final tooLong = facility('tooLong', 35.6311, 139.8811, duration: 120);
    final preferences = [
      PlanPreference.initial(facilityId: pickup.id)
          .copyWith(priority: PriorityLevel.high),
      PlanPreference.initial(facilityId: tooLong.id)
          .copyWith(priority: PriorityLevel.high),
    ];
    final context = ReplanningContext(
      now: DateTime(2026, 8, 12, 13, 0),
      nextFixedStartMinutes: 14 * 60,
      currentFacility: from,
      nextDestination: destination,
      facilities: [pickup, tooLong],
      preferences: preferences,
    );

    final pickupIds = service
        .assess(context)
        .where((item) => item.type == ReplanningActionType.routePickup)
        .map((item) => item.facilityId)
        .toSet();

    expect(pickupIds, contains('pickup'));
    expect(pickupIds, isNot(contains('tooLong')));
  });
}
