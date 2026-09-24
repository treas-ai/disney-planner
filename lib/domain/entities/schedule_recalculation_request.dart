import 'day_schedule.dart';
import 'facility.dart';
import 'live_operating_status.dart';
import 'live_wait_time.dart';
import 'plan_preference.dart';
import 'trip_settings.dart';
import 'time_band_wait_profile.dart';
import 'weather_snapshot.dart';
import 'today_access_result.dart';
import 'today_execution_record.dart';
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
    this.waitProfiles = const <TimeBandWaitProfile>[],
    this.releasedFacilityIds = const <String>{},
    this.todayAccessResults = const <TodayAccessResult>[],
    this.executedFacilityIds = const <String>{},
    this.todayExecutionRecords = const <TodayExecutionRecord>[],
    this.currentFacilityId,
    this.breakDurationMinutes,
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
  final List<TimeBandWaitProfile> waitProfiles;
  final Set<String> releasedFacilityIds;

  /// 当日に実際に取得・当選した結果。事前の固定予定と区別して再計算する。
  final List<TodayAccessResult> todayAccessResults;

  /// Facilities already completed or explicitly skipped by the guest today.
  final Set<String> executedFacilityIds;

  /// Actual completed/skipped occurrences with their recorded time.
  /// Used to distinguish elapsed schedule slots from actions that really happened.
  final List<TodayExecutionRecord> todayExecutionRecords;

  /// Explicit current position selected in Today. When null, replanning falls
  /// back to the latest preserved facility for backward compatibility.
  final String? currentFacilityId;

  /// Optional user-requested rest inserted into the live plan.
  /// The service treats it as a fixed anchor and replans only around it.
  final int? breakDurationMinutes;
}
