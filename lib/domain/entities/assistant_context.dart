import 'day_schedule.dart';
import 'facility.dart';

class AssistantContext {
  const AssistantContext({
    required this.now,
    required this.schedule,
    required this.facilities,
  });

  final DateTime now;
  final DaySchedule? schedule;
  final List<Facility> facilities;

  Facility? facilityById(String? facilityId) {
    if (facilityId == null) {
      return null;
    }

    for (final facility in facilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }
}
