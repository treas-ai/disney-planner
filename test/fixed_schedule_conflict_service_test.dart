import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/enums/dining_location_type.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/services/fixed_schedule_conflict_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('park-exit reservation conflicts with a performance inside travel window', () {
    const chef = Facility(
      id: 'chef', parkId: 'tdl', areaId: 'hotel', name: 'シェフ・ミッキー',
      category: FacilityCategory.restaurant,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 90,
      diningLocationType: DiningLocationType.disneyHotel,
      requiresParkExit: true,
      outboundTravelMinutes: 35,
      returnTravelMinutes: 35,
    );
    const parade = Facility(
      id: 'parade', parkId: 'tdl', areaId: 'route', name: 'パレード',
      category: FacilityCategory.show,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 45,
    );
    final chefPreference = PlanPreference.initial(facilityId: 'chef').copyWith(
      reservationTime: '16:00', fixedTimeStatus: FixedTimeStatus.confirmed,
    );
    final paradePreference = PlanPreference.initial(facilityId: 'parade').copyWith(
      preferredPerformanceTime: '16:15', fixedTimeStatus: FixedTimeStatus.confirmed,
    );

    final conflicts = const FixedScheduleConflictService().findConflicts(
      facilities: const [chef, parade],
      preferences: [chefPreference, paradePreference],
    );

    expect(conflicts, hasLength(1));
    expect(conflicts.single, contains('予約16:00'));
    expect(conflicts.single, contains('外出15:25-18:05'));
    expect(conflicts.single, contains('両立できません'));
  });
}
