import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/live_operating_status.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/schedule_recalculation_request.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/schedule_recalculation_service.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('一時運営中止の進行中施設は外し、完了済み・食事・退園を維持する', () {
    const completed = Facility(
      id: 'completed',
      parkId: 'tokyo_disneyland',
      areaId: 'area_a',
      name: '完了済み施設',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );
    const disrupted = Facility(
      id: 'disrupted',
      parkId: 'tokyo_disneyland',
      areaId: 'area_b',
      name: '一時運営中止施設',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );
    const future = Facility(
      id: 'future',
      parkId: 'tokyo_disneyland',
      areaId: 'area_c',
      name: '再配置候補',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );

    final now = DateTime(2026, 10, 5, 13, 30);
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsLunch: false,
      wantsDinner: false,
    );
    final schedule = DaySchedule(
      id: 'before',
      parkId: 'tokyo_disneyland',
      createdAt: now,
      items: const [
        ScheduleItem(
          id: 'entry',
          title: '入園',
          type: ScheduleItemType.entry,
          startHour: 9,
          startMinute: 0,
          endHour: 9,
          endMinute: 5,
        ),
        ScheduleItem(
          id: 'completed',
          title: '完了済み施設',
          type: ScheduleItemType.facility,
          startHour: 12,
          startMinute: 0,
          endHour: 12,
          endMinute: 20,
          facilityId: 'completed',
        ),
        ScheduleItem(
          id: 'disrupted',
          title: '一時運営中止施設',
          type: ScheduleItemType.facility,
          startHour: 13,
          startMinute: 20,
          endHour: 13,
          endMinute: 50,
          facilityId: 'disrupted',
        ),
        ScheduleItem(
          id: 'lunch',
          title: '食事',
          type: ScheduleItemType.lunch,
          startHour: 14,
          startMinute: 0,
          endHour: 14,
          endMinute: 30,
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
        now: now,
        currentSchedule: schedule,
        settings: settings,
        facilities: const [completed, disrupted, future],
        preferences: [
          PlanPreference.initial(facilityId: completed.id),
          PlanPreference.initial(facilityId: disrupted.id),
          PlanPreference.initial(facilityId: future.id),
        ],
        waitTimes: const {},
        operatingStatuses: {
          disrupted.id: LiveOperatingStatus(
            parkId: 'tokyo_disneyland',
            facilityId: disrupted.id,
            state: LiveOperatingState.temporarilyClosed,
            updatedAt: now,
          ),
        },
      ),
    );

    expect(
      result.afterSchedule.items.any((item) => item.id == 'completed'),
      isTrue,
    );
    expect(
      result.afterSchedule.items.any((item) => item.id == 'disrupted'),
      isFalse,
    );
    expect(
      result.afterSchedule.items.any((item) => item.id == 'lunch'),
      isTrue,
    );
    expect(
      result.afterSchedule.items.any((item) => item.id == 'exit'),
      isTrue,
    );
    expect(
      result.afterSchedule.items.any((item) => item.facilityId == 'future'),
      isTrue,
    );
    expect(
      result.warnings.any((message) => message.contains('一時休止')),
      isTrue,
    );
  });

  test('シミュレーション待ち時間は実データを保存せず再最適化の拘束時間へ反映する', () {
    const target = Facility(
      id: 'target',
      parkId: 'tokyo_disneyland',
      areaId: 'area_a',
      name: '待ち時間変化対象',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );

    final now = DateTime(2026, 10, 5, 13, 0);
    final settings = TripSettings.initial().copyWith(
      parkId: 'tokyo_disneyland',
      visitDateIso: '2026-10-05T00:00:00.000',
      entryTimeHour: 9,
      entryTimeMinute: 0,
      exitTimeHour: 21,
      exitTimeMinute: 0,
      wantsLunch: false,
      wantsDinner: false,
    );
    final schedule = DaySchedule(
      id: 'before_wait_change',
      parkId: 'tokyo_disneyland',
      createdAt: now,
      items: const [
        ScheduleItem(
          id: 'entry',
          title: '入園',
          type: ScheduleItemType.entry,
          startHour: 9,
          startMinute: 0,
          endHour: 9,
          endMinute: 5,
        ),
        ScheduleItem(
          id: 'target',
          title: '待ち時間変化対象',
          type: ScheduleItemType.facility,
          startHour: 13,
          startMinute: 30,
          endHour: 13,
          endMinute: 50,
          facilityId: 'target',
          estimatedWaitMinutes: 10,
          experienceMinutes: 10,
          waitEstimateSource: 'プラン作成時の計画値',
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
        now: now,
        currentSchedule: schedule,
        settings: settings,
        facilities: const [target],
        preferences: [
          PlanPreference.initial(facilityId: target.id),
        ],
        waitTimes: const {},
        operatingStatuses: const {},
      ),
      simulatedWaitMinutesByFacilityId: const {'target': 60},
    );

    final replanned = result.afterSchedule.items
        .where((item) => item.facilityId == 'target')
        .first;
    expect(replanned.estimatedWaitMinutes, 60);
    expect(
      replanned.endHour * 60 + replanned.endMinute -
          (replanned.startHour * 60 + replanned.startMinute),
      70,
    );
    expect(
      result.warnings.any((message) => message.contains('シミュレーション60分')),
      isTrue,
    );
  });

}
