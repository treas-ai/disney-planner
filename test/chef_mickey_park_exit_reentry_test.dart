import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/dining_location_type.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chef Mickey reservation blocks park exit travel meal return and reentry', () {
    const chefMickey = Facility(
      id: 'tdl_hotel_r_004',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_resort_hotels',
      name: 'シェフ・ミッキー',
      category: FacilityCategory.restaurant,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 90,
      requiresReservation: true,
      reservationRequired: true,
      supportsPrioritySeating: true,
      diningLocationType: DiningLocationType.disneyHotel,
      requiresParkExit: true,
      hotelId: 'ambassador_hotel',
      outboundTravelMinutes: 35,
      returnTravelMinutes: 35,
    );

    final preference = PlanPreference.initial(facilityId: chefMickey.id).copyWith(
      reservationTime: '16:00',
      fixedTimeStatus: FixedTimeStatus.confirmed,
    );
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-11-15T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsBreakfast: false,
      wantsLunch: false,
      wantsDinner: false,
    );

    final schedule = const ScheduleEngine().generate(
      settings: settings,
      facilities: const [chefMickey],
      preferences: [preference],
    );

    final item = schedule.items.singleWhere(
      (candidate) => candidate.id == 'fixed_restaurant_${chefMickey.id}',
    );
    expect(item.startTimeLabel, '15:25');
    expect(item.endTimeLabel, '18:05');
    expect(item.reason, contains('往復移動'));

    final overlaps = schedule.items.where((candidate) {
      if (candidate.id == item.id ||
          candidate.id == 'entry' ||
          candidate.id == 'exit') {
        return false;
      }
      final start = candidate.startHour * 60 + candidate.startMinute;
      final end = candidate.endHour * 60 + candidate.endMinute;
      return start < 18 * 60 + 5 && end > 15 * 60 + 25;
    });
    expect(overlaps, isEmpty);
  });
}
