import 'package:disney_planner/domain/entities/area_connection.dart';
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

  test('movement evaluation uses travel minutes and penalizes long backtracking', () {
    final facilities = [
      facility(id: 'a1', areaId: 'area_a', name: 'A1'),
      facility(id: 'b1', areaId: 'area_b', name: 'B1'),
      facility(id: 'c1', areaId: 'area_c', name: 'C1'),
    ];
    final schedule = DaySchedule(
      id: 'movement_distance',
      parkId: 'tokyo_disneysea',
      items: [
        item(id: 'a1', facilityId: 'a1', hour: 9),
        item(id: 'c1', facilityId: 'c1', hour: 10),
        item(id: 'a1_again', facilityId: 'a1', hour: 11),
      ],
      createdAt: DateTime(2026),
    );
    final connections = [
      const AreaConnection(
        parkId: 'tokyo_disneysea',
        fromAreaId: 'area_a',
        toAreaId: 'area_b',
        minutes: 4,
        bidirectional: true,
      ),
      const AreaConnection(
        parkId: 'tokyo_disneysea',
        fromAreaId: 'area_b',
        toAreaId: 'area_c',
        minutes: 9,
        bidirectional: true,
      ),
    ];

    final result = engine.optimize(
      schedule: schedule,
      facilities: facilities,
      preferences: facilities
          .map((value) => PlanPreference.initial(facilityId: value.id))
          .toList(),
      predictions: const {},
      settings: TripSettings.initial(),
      areaConnections: connections,
    );

    expect(result.beforeMetrics.walkingMinutes, 26);
    expect(result.beforeMetrics.longDistanceMoves, 2);
    expect(result.beforeMetrics.longDistanceBacktracks, 1);
    expect(
      result.dimensions.firstWhere((value) => value.label == '移動効率').message,
      contains('推定徒歩'),
    );
  });


}
