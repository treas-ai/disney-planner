import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'official performance remains fixed even when it ends after exit setting',
    () {
      const facility = Facility(
        id: 'tdl_world_bazaar_reach_for_the_stars',
        parkId: 'tokyo_disneyland',
        areaId: 'tdl_world_bazaar',
        name: 'リーチ・フォー・ザ・スターズ：エバーラスティング・ドリームス',
        category: FacilityCategory.show,
        coordinate: Coordinate(latitude: 0, longitude: 0),
        durationMinutes: 25,
      );
      final preference = PlanPreference.initial(facilityId: facility.id)
          .copyWith(
            fixedTimeStatus: FixedTimeStatus.confirmed,
            preferredPerformanceTime: '20:55',
            selectedPerformanceIndex: 0,
          );
      final settings = TripSettings.initial().copyWith(
        parkId: 'tokyo_disneyland',
        exitTimeHour: 21,
        exitTimeMinute: 0,
      );

      final schedule = const ScheduleEngine().generate(
        settings: settings,
        facilities: const [facility],
        preferences: [preference],
      );

      final show = schedule.items.singleWhere(
        (item) => item.facilityId == facility.id,
      );
      final exit = schedule.items.singleWhere(
        (item) => item.type == ScheduleItemType.exit,
      );
      expect(show.startHour, 20);
      expect(show.startMinute, 55);
      expect(
        exit.startHour * 60 + exit.startMinute,
        greaterThanOrEqualTo(21 * 60 + 20),
      );
    },
  );
}
