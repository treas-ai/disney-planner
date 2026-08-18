import 'day_schedule.dart';
import 'facility.dart';
import 'live_operating_status.dart';
import 'live_wait_time.dart';
import 'plan_preference.dart';
import 'trip_settings.dart';
import 'weather_snapshot.dart';
import 'live_pass_status.dart';
import '../enums/fatigue_level.dart';

class ScheduleRecalculationRequest {
  const ScheduleRecalculationRequest({
    required this.now,
    required this.currentSchedule,
    required this.settings,
    required this.facilities,
    required this.preferences,
    required this.waitTimes,
    required this.operatingStatuses,
    this.weather,
    this.passStatuses = const <LivePassStatus>[],
    this.fatigueLevel = FatigueLevel.low,
    this.hasBaggage = false,
    this.hotelBreakAvailable = false,
  });

  final DateTime now;
  final DaySchedule currentSchedule;
  final TripSettings settings;
  final List<Facility> facilities;
  final List<PlanPreference> preferences;
  final Map<String, LiveWaitTime> waitTimes;
  final Map<String, LiveOperatingStatus> operatingStatuses;
  final WeatherSnapshot? weather;
  final List<LivePassStatus> passStatuses;
  final FatigueLevel fatigueLevel;
  final bool hasBaggage;
  final bool hotelBreakAvailable;
}
