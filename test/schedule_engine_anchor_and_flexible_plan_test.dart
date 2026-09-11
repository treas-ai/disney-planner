import 'package:disney_planner/domain/entities/area_connection.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/facility_location.dart';
import 'package:disney_planner/domain/entities/official_performance_opportunity.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

Facility _facility(
  String id, {
  required String areaId,
  required FacilityCategory category,
  int durationMinutes = 10,
}) {
  return Facility(
    id: id,
    parkId: 'tokyo_disneyland',
    areaId: areaId,
    name: id,
    category: category,
    coordinate: const Coordinate(latitude: 0, longitude: 0),
    durationMinutes: durationMinutes,
  );
}

TripSettings _settings({
  bool wantsLunch = false,
  bool unlimited = false,
}) {
  return TripSettings.initial().copyWith(
    parkId: 'tokyo_disneyland',
    visitDateIso: '2026-10-05T00:00:00.000',
    entryTimeHour: 9,
    entryTimeMinute: 0,
    exitTimeHour: 21,
    exitTimeMinute: 0,
    wantsBreakfast: false,
    wantsLunch: wantsLunch,
    wantsDinner: false,
    usesVacationPackage: unlimited,
    hasUnlimitedAttractionRides: unlimited,
  );
}

void main() {
  test('食事直前にも次の施設までの移動時間を確保する', () {
    final meal = _facility(
      'meal',
      areaId: 'east',
      category: FacilityCategory.restaurant,
      durationMinutes: 30,
    );
    final ride = _facility(
      'west_ride',
      areaId: 'west',
      category: FacilityCategory.attraction,
      durationMinutes: 30,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(wantsLunch: true).copyWith(entryTimeHour: 11),
      facilities: [meal, ride],
      preferences: [
        PlanPreference.initial(facilityId: meal.id),
        PlanPreference.initial(facilityId: ride.id),
      ],
      areaConnections: const [
        AreaConnection(
          parkId: 'tokyo_disneyland',
          fromAreaId: 'east',
          toAreaId: 'west',
          minutes: 20,
          bidirectional: true,
        ),
      ],
      facilityLocations: const [
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'meal',
          areaId: 'east',
          x: 0,
          y: 0,
        ),
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'west_ride',
          areaId: 'west',
          x: 1,
          y: 0,
        ),
      ],
    );

    final mealItem = schedule.items.singleWhere((item) => item.facilityId == 'meal');
    final rideItem = schedule.items.singleWhere((item) => item.facilityId == 'west_ride');
    final mealStart = mealItem.startHour * 60 + mealItem.startMinute;
    final mealEnd = mealItem.endHour * 60 + mealItem.endMinute;
    final rideStart = rideItem.startHour * 60 + rideItem.startMinute;
    final rideEnd = rideItem.endHour * 60 + rideItem.endMinute;

    final safelyBeforeMeal = rideEnd + 20 <= mealStart;
    final safelyAfterMeal = rideStart >= mealEnd + 20;
    expect(safelyBeforeMeal || safelyAfterMeal, isTrue);
  });

  test('到達と15分準備が間に合わないエントリー受付公演は候補表示しない', () {
    final fixed = _facility(
      'fixed_access',
      areaId: 'west',
      category: FacilityCategory.attraction,
      durationMinutes: 30,
    );
    final show = _facility(
      'entry_show',
      areaId: 'east',
      category: FacilityCategory.show,
      durationMinutes: 25,
    );
    final fixedPreference = PlanPreference.initial(facilityId: fixed.id).copyWith(
      accessMethod: FacilityAccessMethod.reservation,
      fixedTimeStatus: FixedTimeStatus.confirmed,
      scheduledAccessTime: '13:18',
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(),
      facilities: [fixed, show],
      preferences: [
        fixedPreference,
        PlanPreference.initial(facilityId: show.id),
      ],
      areaConnections: const [
        AreaConnection(
          parkId: 'tokyo_disneyland',
          fromAreaId: 'west',
          toAreaId: 'east',
          minutes: 15,
          bidirectional: true,
        ),
      ],
      facilityLocations: const [
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'fixed_access',
          areaId: 'west',
          x: 0,
          y: 0,
        ),
        FacilityLocation(
          parkId: 'tokyo_disneyland',
          facilityId: 'entry_show',
          areaId: 'east',
          x: 1,
          y: 0,
        ),
      ],
      officialPerformanceOpportunities: const [
        OfficialPerformanceOpportunity(
          facilityId: 'entry_show',
          name: 'Entry Show',
          startMinutes: 14 * 60,
          endMinutes: 14 * 60 + 25,
          requiresEntryRequest: true,
        ),
        OfficialPerformanceOpportunity(
          facilityId: 'entry_show',
          name: 'Entry Show',
          startMinutes: 15 * 60,
          endMinutes: 15 * 60 + 25,
          requiresEntryRequest: true,
        ),
      ],
    );

    final flexText = schedule.items
        .where((item) => item.type == ScheduleItemType.breakTime)
        .map((item) => '${item.reason} ${item.note}')
        .join(' ');
    expect(flexText, isNot(contains('14:00 Entry Show')));
    expect(flexText, contains('15:00 Entry Show'));
  });

  test('乗り放題でも同一アトラクションを自動で複数回追加しない', () {
    final ride = _facility(
      'unlimited_ride',
      areaId: 'east',
      category: FacilityCategory.attraction,
      durationMinutes: 10,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(unlimited: true),
      facilities: [ride],
      preferences: [PlanPreference.initial(facilityId: ride.id)],
      unlimitedRideBufferMinutes: const {'unlimited_ride': 15},
    );

    final uses = schedule.items.where((item) => item.facilityId == ride.id);
    expect(uses.length, 1);
    expect(
      schedule.items.any((item) => item.id.startsWith('provisional_unlimited_')),
      isFalse,
    );
  });

  test('ユーザーが明示した乗り放題再乗車は2回目として保持できる', () {
    final ride = _facility(
      'unlimited_ride',
      areaId: 'east',
      category: FacilityCategory.attraction,
      durationMinutes: 10,
    );

    final schedule = const ScheduleEngine().generate(
      settings: _settings(unlimited: true),
      facilities: [ride],
      preferences: [PlanPreference.initial(facilityId: ride.id)],
      unlimitedRideBufferMinutes: const {'unlimited_ride': 15},
      manualFixedItems: const [
        ScheduleItem(
          id: 'manual_repeat_20261005_unlimited_ride_1',
          title: 'unlimited_ride（2回目）',
          type: ScheduleItemType.facility,
          startHour: 14,
          startMinute: 0,
          endHour: 14,
          endMinute: 25,
          facilityId: 'unlimited_ride',
          estimatedWaitMinutes: 15,
          experienceMinutes: 10,
          waitEstimateSource: 'バケパ乗り放題の優先入口利用バッファ',
        ),
      ],
    );

    final uses = schedule.items
        .where((item) => item.facilityId == ride.id)
        .toList(growable: false);
    expect(uses.length, 2);
    expect(
      uses.any((item) => item.id.startsWith('manual_repeat_20261005_')),
      isTrue,
    );
  });

}
