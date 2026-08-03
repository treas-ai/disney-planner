import 'day_schedule.dart';
import 'event_impact.dart';
import 'facility.dart';

class AssistantContext {
  const AssistantContext({
    required this.now,
    required this.schedule,
    required this.facilities,
    this.eventImpacts = const [],
  });

  final DateTime now;
  final DaySchedule? schedule;
  final List<Facility> facilities;
  final List<EventImpact> eventImpacts;

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
