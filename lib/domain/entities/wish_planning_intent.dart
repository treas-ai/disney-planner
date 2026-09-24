import '../enums/preferred_time.dart';
import '../enums/priority_level.dart';
import '../enums/wait_tolerance.dart';
import '../enums/wish_importance.dart';

/// Planner-facing interpretation of one or more user wishes that resolve to
/// the same facility. It deliberately contains no DPA/VP/access-method state:
/// those are execution choices, not user intent.
class WishPlanningIntent {
  const WishPlanningIntent({
    required this.facilityId,
    required this.importance,
    required this.targetCount,
    required this.preferredTime,
    required this.waitTolerance,
  });

  final String facilityId;
  final WishImportance importance;
  final int targetCount;
  final PreferredTime preferredTime;
  final WaitTolerance waitTolerance;

  PriorityLevel get planPriority => switch (importance) {
        WishImportance.mustDo => PriorityLevel.highest,
        WishImportance.normal => PriorityLevel.high,
        WishImportance.optional => PriorityLevel.low,
      };
}
