import 'day_schedule.dart';
import 'plan_optimization_dimension.dart';

class PlanOptimizationResult {
  const PlanOptimizationResult({
    required this.beforeSchedule,
    required this.afterSchedule,
    required this.beforeScore,
    required this.afterScore,
    required this.dimensions,
    required this.recommendations,
    required this.createdAt,
  });

  final DaySchedule beforeSchedule;
  final DaySchedule afterSchedule;
  final int beforeScore;
  final int afterScore;
  final List<PlanOptimizationDimension> dimensions;
  final List<String> recommendations;
  final DateTime createdAt;

  bool get hasImprovement => afterScore > beforeScore;
}
