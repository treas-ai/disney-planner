import 'trip_settings.dart';

class PhaseDScenarioSummary {
  const PhaseDScenarioSummary({
    required this.mode,
    required this.achievedDesiredCount,
    required this.totalDesiredCount,
    required this.hardAchievedCount,
    required this.totalHardDesiredCount,
    required this.totalWaitMinutes,
    required this.totalMovementMinutes,
    required this.totalFreeMinutes,
    required this.largestFreeBlockMinutes,
    required this.overlapCount,
  });

  final ScheduleOptimizationMode mode;
  final int achievedDesiredCount;
  final int totalDesiredCount;
  final int hardAchievedCount;
  final int totalHardDesiredCount;
  final int totalWaitMinutes;
  final int totalMovementMinutes;
  final int totalFreeMinutes;
  final int largestFreeBlockMinutes;
  final int overlapCount;
}
