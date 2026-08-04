import 'day_schedule.dart';
import 'plan_optimization_dimension.dart';
import 'smart_schedule_metrics.dart';

class PlanOptimizationResult {
  const PlanOptimizationResult({
    required this.beforeSchedule,
    required this.afterSchedule,
    required this.beforeScore,
    required this.afterScore,
    required this.beforeMetrics,
    required this.afterMetrics,
    required this.dimensions,
    required this.recommendations,
    required this.createdAt,
  });

  final DaySchedule beforeSchedule;
  final DaySchedule afterSchedule;
  final int beforeScore;
  final int afterScore;
  final SmartScheduleMetrics beforeMetrics;
  final SmartScheduleMetrics afterMetrics;
  final List<PlanOptimizationDimension> dimensions;
  final List<String> recommendations;
  final DateTime createdAt;

  bool get hasImprovement => afterScore > beforeScore;
}
