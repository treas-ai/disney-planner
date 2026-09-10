import 'package:disney_planner/domain/entities/area_connection.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/facility_location.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/preferred_time.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _restaurant(String id, int order) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: 'tdl_test',
    name: id,
    category: FacilityCategory.restaurant,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: 30,
    displayOrder: order,
  );
}

void main() {
  test('meal slotに採用されなかったレストランを通常施設として追加しない', () {
    final first = _restaurant('restaurant_a', 1);
    final second = _restaurant('restaurant_b', 2);
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-08-21T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsBreakfast: false,
      wantsLunch: true,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: [first, second],
      preferences: [
        PlanPreference.initial(facilityId: first.id),
        PlanPreference.initial(facilityId: second.id),
      ],
    );

    final restaurantItems = schedule.items
        .where((item) => item.facilityId == first.id || item.facilityId == second.id)
        .toList(growable: false);
    expect(restaurantItems, hasLength(1));
  });

  test('食事直後の別エリア施設には移動時間を確保する', () {
    final restaurant = Facility(
      id: 'restaurant_meal',
      parkId: 'tokyo_disneyland',
      areaId: 'area_meal',
      name: 'Restaurant',
      category: FacilityCategory.restaurant,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 60,
      displayOrder: 1,
    );
    final attraction = Facility(
      id: 'attraction_after_meal',
      parkId: 'tokyo_disneyland',
      areaId: 'area_ride',
      name: 'Attraction',
      category: FacilityCategory.attraction,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 20,
      displayOrder: 2,
    );
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsBreakfast: false,
      wantsLunch: true,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: [restaurant, attraction],
      preferences: [
        PlanPreference.initial(facilityId: restaurant.id),
        PlanPreference.initial(facilityId: attraction.id).copyWith(
          preferredTime: PreferredTime.afternoon,
        ),
      ],
      areaConnections: const [
        AreaConnection(
          parkId: 'tokyo_disneyland',
          fromAreaId: 'area_meal',
          toAreaId: 'area_ride',
          minutes: 15,
        ),
      ],
      facilityLocations: const [
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'restaurant_meal',
          areaId: 'area_meal',
          x: 0,
          y: 0,
        ),
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'attraction_after_meal',
          areaId: 'area_ride',
          x: 1,
          y: 0,
        ),
      ],
    );

    final meal = schedule.items.singleWhere(
      (item) => item.facilityId == restaurant.id,
    );
    final ride = schedule.items.singleWhere(
      (item) => item.facilityId == attraction.id,
    );
    final mealEnd = meal.endHour * 60 + meal.endMinute;
    final rideStart = ride.startHour * 60 + ride.startMinute;

    expect(rideStart, greaterThanOrEqualTo(mealEnd + 15));
  });

}
