import '../enums/fatigue_level.dart';
import 'facility.dart';
import 'live_pass_status.dart';
import 'plan_preference.dart';
import 'weather_snapshot.dart';

class ReplanningContext {
  const ReplanningContext({
    required this.now,
    required this.facilities,
    required this.preferences,
    this.nextFixedStartMinutes,
    this.currentFacility,
    this.nextDestination,
    this.weather,
    this.passStatuses = const <LivePassStatus>[],
    this.fatigueLevel = FatigueLevel.low,
    this.hasBaggage = false,
    this.hotelBreakAvailable = false,
    this.fixedScheduleSafetyBufferMinutes = 15,
  });

  final DateTime now;
  final List<Facility> facilities;
  final List<PlanPreference> preferences;
  final int? nextFixedStartMinutes;
  final Facility? currentFacility;
  final Facility? nextDestination;
  final WeatherSnapshot? weather;
  final List<LivePassStatus> passStatuses;
  final FatigueLevel fatigueLevel;
  final bool hasBaggage;
  final bool hotelBreakAvailable;
  final int fixedScheduleSafetyBufferMinutes;

  int get nowMinutes => now.hour * 60 + now.minute;

  int? get usableMinutesBeforeFixed {
    final fixed = nextFixedStartMinutes;
    if (fixed == null) return null;
    final value = fixed - nowMinutes - fixedScheduleSafetyBufferMinutes;
    return value < 0 ? 0 : value;
  }
}
