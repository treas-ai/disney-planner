import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
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
}
