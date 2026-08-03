import 'day_schedule.dart';
import 'facility.dart';
import 'live_operating_status.dart';
import 'live_wait_time.dart';
import 'plan_preference.dart';
import 'trip_settings.dart';

class ScheduleRecalculationRequest {
  const ScheduleRecalculationRequest({
    required this.now,
    required this.currentSchedule,
    required this.settings,
    required this.facilities,
    required this.preferences,
    required this.waitTimes,
    required this.operatingStatuses,
  });

  final DateTime now;
  final DaySchedule currentSchedule;
  final TripSettings settings;
  final List<Facility> facilities;
  final List<PlanPreference> preferences;
  final Map<String, LiveWaitTime> waitTimes;
  final Map<String, LiveOperatingStatus> operatingStatuses;
}
