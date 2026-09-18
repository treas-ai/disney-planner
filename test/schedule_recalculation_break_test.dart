import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
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
  test('当日の休憩を固定枠として追加し完了済み予定と退園を維持する', () {
    const future = Facility(
      id: 'future',
      parkId: 'tokyo_disneyland',
      areaId: 'area_a',
      name: '残りの施設',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      durationMinutes: 10,
    );
    final now = DateTime(2026, 10, 5, 14, 0);
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
      id: 'before_break',
      parkId: 'tokyo_disneyland',
      createdAt: now,
      items: const [
        ScheduleItem(
          id: 'entry', title: '入園', type: ScheduleItemType.entry,
          startHour: 9, startMinute: 0, endHour: 9, endMinute: 5,
        ),
        ScheduleItem(
          id: 'done', title: '完了済み', type: ScheduleItemType.facility,
          startHour: 12, startMinute: 0, endHour: 12, endMinute: 20,
        ),
        ScheduleItem(
          id: 'future', title: '残りの施設', type: ScheduleItemType.facility,
          startHour: 14, startMinute: 30, endHour: 14, endMinute: 40,
          facilityId: 'future',
        ),
        ScheduleItem(
          id: 'exit', title: '退園', type: ScheduleItemType.exit,
          startHour: 21, startMinute: 0, endHour: 21, endMinute: 0,
        ),
      ],
    );

    final result = const ScheduleRecalculationService().createProposal(
      ScheduleRecalculationRequest(
        now: now,
        currentSchedule: schedule,
        settings: settings,
        facilities: const [future],
        preferences: [PlanPreference.initial(facilityId: future.id)],
        waitTimes: const {},
        operatingStatuses: const {},
        breakDurationMinutes: 20,
      ),
    );

    final rest = result.afterSchedule.items.singleWhere(
      (item) => item.type == ScheduleItemType.breakTime && item.title == 'ひと休み',
    );
    expect(rest.startHour, 14);
    expect(rest.startMinute, 0);
    expect(rest.endHour, 14);
    expect(rest.endMinute, 20);
    expect(result.afterSchedule.items.any((item) => item.id == 'done'), isTrue);
    expect(result.afterSchedule.items.any((item) => item.id == 'exit'), isTrue);
    for (final item in result.afterSchedule.items.where(
      (item) => item.facilityId == future.id,
    )) {
      final start = item.startHour * 60 + item.startMinute;
      final end = item.endHour * 60 + item.endMinute;
      expect(end <= 14 * 60 || start >= 14 * 60 + 20, isTrue);
    }
  });
}
