import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/priority_level.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/services/rule_based_plan_optimization_engine.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = RuleBasedPlanOptimizationEngine();

  Facility facility({
    required String id,
    required String areaId,
    required String name,
    bool indoor = false,
  }) {
    return Facility(
      id: id,
      parkId: 'tokyo_disneysea',
      areaId: areaId,
      name: name,
      category: FacilityCategory.attraction,
      coordinate: const Coordinate(latitude: 0, longitude: 0),
      isIndoor: indoor,
    );
  }

  ScheduleItem item({
    required String id,
    required String facilityId,
    required int hour,
  }) {
    return ScheduleItem(
      id: id,
      title: id,
      type: ScheduleItemType.facility,
      startHour: hour,
      startMinute: 0,
      endHour: hour,
      endMinute: 30,
      facilityId: facilityId,
      reason: '',
    );
  }

  test(
    'same-area facilities are grouped while fixed meal time is protected',
    () {
      final facilities = [
        facility(id: 'a1', areaId: 'area_a', name: 'A1'),
        facility(id: 'b1', areaId: 'area_b', name: 'B1'),
        facility(id: 'a2', areaId: 'area_a', name: 'A2'),
      ];
      final lunch = const ScheduleItem(
        id: 'lunch',
        title: '昼食',
        type: ScheduleItemType.lunch,
        startHour: 12,
        startMinute: 0,
        endHour: 13,
        endMinute: 0,
        reason: '',
      );
      final schedule = DaySchedule(
        id: 'before',
        parkId: 'tokyo_disneysea',
        items: [
          item(id: 'a1', facilityId: 'a1', hour: 9),
          item(id: 'b1', facilityId: 'b1', hour: 10),
          item(id: 'a2', facilityId: 'a2', hour: 11),
          lunch,
        ],
        createdAt: DateTime(2026),
      );

      final result = engine.optimize(
        schedule: schedule,
        facilities: facilities,
        preferences: facilities
            .map((value) => PlanPreference.initial(facilityId: value.id))
            .toList(),
        predictions: const {},
        settings: TripSettings.initial(),
      );

      final lunchAfter = result.afterSchedule.items.singleWhere(
        (value) => value.id == 'lunch',
      );
      expect(lunchAfter.startHour, 12);
      expect(
        result.afterMetrics.areaTransitions,
        lessThanOrEqualTo(result.beforeMetrics.areaTransitions),
      );
    },
  );

  test('rainy settings prefer indoor facility for an earlier slot', () {
    final facilities = [
      facility(id: 'outdoor', areaId: 'area_a', name: 'Outdoor'),
      facility(id: 'indoor', areaId: 'area_b', name: 'Indoor', indoor: true),
    ];
    final schedule = DaySchedule(
      id: 'rain',
      parkId: 'tokyo_disneysea',
      items: [
        item(id: 'outdoor', facilityId: 'outdoor', hour: 9),
        item(id: 'indoor', facilityId: 'indoor', hour: 10),
      ],
      createdAt: DateTime(2026),
    );

    final result = engine.optimize(
      schedule: schedule,
      facilities: facilities,
      preferences: [
        PlanPreference.initial(
          facilityId: 'outdoor',
        ).copyWith(priority: PriorityLevel.medium),
        PlanPreference.initial(
          facilityId: 'indoor',
        ).copyWith(priority: PriorityLevel.medium),
      ],
      predictions: const {},
      settings: TripSettings.initial().copyWith(isRainy: true),
    );

    expect(result.afterSchedule.items.first.facilityId, 'indoor');
  });
}
