import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/schedule_item.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/schedule_item_type.dart';
import 'package:disney_planner/domain/enums/schedule_validation_severity.dart';
import 'package:disney_planner/domain/services/schedule_validator.dart';
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
      issues.any(
        (issue) => issue.severity == ScheduleValidationSeverity.error,
      ),
      isTrue,
    );
  });
}
