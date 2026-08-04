import '../entities/day_schedule.dart';
import '../entities/event_impact.dart';
import '../entities/facility.dart';
import '../entities/plan_optimization_result.dart';
import '../entities/plan_preference.dart';
import '../entities/trip_settings.dart';
import '../entities/wait_time_prediction.dart';

abstract interface class PlanOptimizationEngine {
  PlanOptimizationResult optimize({
    required DaySchedule schedule,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required Map<String, WaitTimePrediction> predictions,
    required TripSettings settings,
    List<EventImpact> eventImpacts = const [],
  });
}
