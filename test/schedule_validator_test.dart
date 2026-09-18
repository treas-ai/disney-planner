import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/enums/schedule_validation_severity.dart';
import 'package:disney_planner/domain/services/schedule_validator.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ScheduleValidator();

  test('overlapping items produce an error', () {
    final schedule = DaySchedule(
      id: 'test',
      parkId: 'tokyo_disneyland',
      createdAt: DateTime(2026),
      items: const [
        ScheduleItem(
          id: 'a',
          title: 'A',
          type: ScheduleItemType.facility,
          startHour: 10,
          startMinute: 0,
          endHour: 11,
          endMinute: 0,
        ),
        ScheduleItem(
          id: 'b',
          title: 'B',
          type: ScheduleItemType.facility,
          startHour: 10,
          startMinute: 30,
          endHour: 11,
          endMinute: 30,
        ),
      ],
    );

    final issues = validator.validate(
      schedule: schedule,
      settings: TripSettings.initial(),
      preferences: const [],
    );

    expect(
      issues.any((issue) => issue.severity == ScheduleValidationSeverity.error),
      isTrue,
    );
  });

  test('missing desired facility is a warning and not a hard error', () {
    const desired = Facility(
      id: 'desired',
      parkId: 'tdl',
      areaId: 'area',
      name: 'Desired attraction',
      category: FacilityCategory.attraction,
      coordinate: Coordinate(latitude: 0, longitude: 0),
    );
    final schedule = DaySchedule(
      id: 'test-missing',
      parkId: 'tdl',
      createdAt: DateTime(2026),
      items: const [],
    );

    final issues = validator.validate(
      schedule: schedule,
      settings: TripSettings.initial(),
      preferences: [PlanPreference.initial(facilityId: desired.id)],
      facilities: const [desired],
    );

    final missing = issues.singleWhere(
      (issue) => issue.code == 'desired_facility_missing',
    );
    expect(missing.severity, ScheduleValidationSeverity.warning);
    expect(missing.message, contains('今回は'));
  });

}
