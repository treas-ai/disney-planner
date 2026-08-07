import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/restaurant_type.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in-park restaurant without operating hours is not placed before 10:00', () {
    const restaurant = Facility(
      id: 'restaurant_without_hours',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_adventureland',
      name: '営業時間未登録レストラン',
      category: FacilityCategory.restaurant,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 20,
      restaurantType: RestaurantType.bakeryCafe,
    );

    final schedule = const ScheduleEngine().generate(
      settings: TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        entryTimeHour: 9,
        entryTimeMinute: 0,
        queueArrivalTimeHour: 7,
        queueArrivalTimeMinute: 0,
        wantsBreakfast: false,
        wantsLunch: false,
        wantsDinner: false,
      ),
      facilities: const [restaurant],
      preferences: [PlanPreference.initial(facilityId: restaurant.id)],
    );

    final item = schedule.items.singleWhere(
      (value) => value.facilityId == restaurant.id,
    );

    expect(item.startHour * 60 + item.startMinute, greaterThanOrEqualTo(600));
  });
}
