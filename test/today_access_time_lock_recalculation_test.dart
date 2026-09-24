import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/schedule_recalculation_request.dart';
import 'package:disney_planner/domain/entities/today_access_result.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/enums/today_access_kind.dart';
import 'package:disney_planner/domain/enums/today_access_status.dart';
import 'package:disney_planner/domain/services/schedule_recalculation_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('当日取得したDPA実時刻は固定し、既存固定予定との競合を警告する', () {
    const ride = Facility(
      id: 'beauty',
      parkId: 'tokyo_disneyland',
      areaId: 'fantasyland',
      name: '美女と野獣“魔法のものがたり”',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 8,
      supportsDpa: true,
    );
    const parade = Facility(
      id: 'villains',
      parkId: 'tokyo_disneyland',
      areaId: 'parade_route',
      name: 'ザ・ヴィランズ・ハロウィーン',
      category: FacilityCategory.parade,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 45,
    );

    final ridePreference = PlanPreference.initial(facilityId: ride.id).copyWith(
      accessMethod: FacilityAccessMethod.dpa,
      useDpa: true,
      scheduledAccessTime: '16:00',
      fixedTimeStatus: FixedTimeStatus.confirmed,
    );
    final paradePreference =
        PlanPreference.initial(facilityId: parade.id).copyWith(
      preferredPerformanceTime: '16:15',
      fixedTimeStatus: FixedTimeStatus.confirmed,
    );

    final schedule = DaySchedule(
      id: 'before',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5, 15, 30),
      items: const [
        ScheduleItem(
          id: 'entry',
          title: '入園',
          type: ScheduleItemType.entry,
          startHour: 9,
          startMinute: 10,
          endHour: 9,
          endMinute: 15,
        ),
        ScheduleItem(
          id: 'villains',
          title: 'ザ・ヴィランズ・ハロウィーン',
          type: ScheduleItemType.facility,
          startHour: 16,
          startMinute: 15,
          endHour: 17,
          endMinute: 0,
          facilityId: 'villains',
          reason: '希望公演時刻へ固定配置しました。',
        ),
        ScheduleItem(
          id: 'beauty',
          title: '美女と野獣“魔法のものがたり”',
          type: ScheduleItemType.facility,
          startHour: 17,
          startMinute: 15,
          endHour: 17,
          endMinute: 33,
          facilityId: 'beauty',
          experienceMinutes: 8,
          priorityAccessBufferMinutes: 10,
          accessMethod: FacilityAccessMethod.dpa,
        ),
        ScheduleItem(
          id: 'exit',
          title: '退園',
          type: ScheduleItemType.exit,
          startHour: 21,
          startMinute: 0,
          endHour: 21,
          endMinute: 0,
        ),
      ],
    );

    final result = const ScheduleRecalculationService().createProposal(
      ScheduleRecalculationRequest(
        now: DateTime(2026, 10, 5, 15, 30),
        currentSchedule: schedule,
        settings: TripSettings.initial().copyWith(
          parkId: 'tokyo_disneyland',
          visitDateIso: '2026-10-05T00:00:00.000',
          entryTimeHour: 9,
          entryTimeMinute: 10,
          exitTimeHour: 21,
          exitTimeMinute: 0,
          wantsLunch: false,
          wantsDinner: false,
        ),
        facilities: const [ride, parade],
        preferences: [ridePreference, paradePreference],
        waitTimes: const {},
        operatingStatuses: const {},
        todayAccessResults: [
          TodayAccessResult(
            facilityId: 'beauty',
            kind: TodayAccessKind.attractionDpa,
            status: TodayAccessStatus.acquired,
            time: '16:00',
            updatedAt: DateTime(2026, 10, 5, 15, 20),
          ),
        ],
      ),
    );

    final beauty = result.afterSchedule.items
        .firstWhere((item) => item.facilityId == 'beauty');
    expect(beauty.startTimeLabel, '16:00');
    expect(beauty.endTimeLabel, '16:18');
    expect(beauty.reason, contains('実際に取得'));
    expect(result.warnings.join('\n'), contains('競合します'));
  });

  test('取得済みDPAと重なる未確定の食事は固定せず再配置対象にする', () {
    const ride = Facility(
      id: 'beauty',
      parkId: 'tokyo_disneyland',
      areaId: 'fantasyland',
      name: '美女と野獣“魔法のものがたり”',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 8,
      supportsDpa: true,
    );
    const meal = Facility(
      id: 'gaston',
      parkId: 'tokyo_disneyland',
      areaId: 'fantasyland',
      name: 'ラ・タベルヌ・ド・ガストン',
      category: FacilityCategory.restaurant,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 30,
    );

    final ridePreference = PlanPreference.initial(facilityId: ride.id).copyWith(
      accessMethod: FacilityAccessMethod.dpa,
      useDpa: true,
      scheduledAccessTime: '15:00',
      fixedTimeStatus: FixedTimeStatus.none,
    );
    final mealPreference = PlanPreference.initial(facilityId: meal.id);

    final schedule = DaySchedule(
      id: 'before-flexible-meal-conflict',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026, 10, 5, 13, 30),
      items: const [
        ScheduleItem(
          id: 'entry',
          title: '入園',
          type: ScheduleItemType.entry,
          startHour: 9,
          startMinute: 10,
          endHour: 9,
          endMinute: 15,
        ),
        ScheduleItem(
          id: 'gaston',
          title: 'ラ・タベルヌ・ド・ガストン',
          type: ScheduleItemType.lunch,
          startHour: 13,
          startMinute: 50,
          endHour: 14,
          endMinute: 20,
          facilityId: 'gaston',
        ),
        ScheduleItem(
          id: 'beauty',
          title: '美女と野獣“魔法のものがたり”',
          type: ScheduleItemType.facility,
          startHour: 15,
          startMinute: 0,
          endHour: 15,
          endMinute: 18,
          facilityId: 'beauty',
          experienceMinutes: 8,
          priorityAccessBufferMinutes: 10,
          accessMethod: FacilityAccessMethod.dpa,
        ),
        ScheduleItem(
          id: 'exit',
          title: '退園',
          type: ScheduleItemType.exit,
          startHour: 21,
          startMinute: 0,
          endHour: 21,
          endMinute: 0,
        ),
      ],
    );

    final result = const ScheduleRecalculationService().createProposal(
      ScheduleRecalculationRequest(
        now: DateTime(2026, 10, 5, 13, 30),
        currentSchedule: schedule,
        settings: TripSettings.initial().copyWith(
          parkId: 'tokyo_disneyland',
          visitDateIso: '2026-10-05T00:00:00.000',
          entryTimeHour: 9,
          entryTimeMinute: 10,
          exitTimeHour: 21,
          exitTimeMinute: 0,
          wantsLunch: false,
          wantsDinner: false,
        ),
        facilities: const [ride, meal],
        preferences: [ridePreference, mealPreference],
        waitTimes: const {},
        operatingStatuses: const {},
        todayAccessResults: [
          TodayAccessResult(
            facilityId: 'beauty',
            kind: TodayAccessKind.attractionDpa,
            status: TodayAccessStatus.acquired,
            time: '14:00',
            updatedAt: DateTime(2026, 10, 5, 13, 20),
          ),
        ],
      ),
    );

    final beauty = result.afterSchedule.items
        .firstWhere((item) => item.facilityId == 'beauty');
    expect(beauty.startTimeLabel, '14:00');
    expect(beauty.endTimeLabel, '14:18');

    final gastonItems = result.afterSchedule.items
        .where((item) => item.facilityId == 'gaston');
    for (final gaston in gastonItems) {
      final gastonStart = gaston.startHour * 60 + gaston.startMinute;
      final gastonEnd = gaston.endHour * 60 + gaston.endMinute;
      final beautyStart = beauty.startHour * 60 + beauty.startMinute;
      final beautyEnd = beauty.endHour * 60 + beauty.endMinute;
      expect(gastonStart < beautyEnd && gastonEnd > beautyStart, isFalse);
    }
    expect(
      result.warnings.join('\n'),
      contains('固定アクセスを優先して再配置します'),
    );
  });

}
