import '../entities/wish_item.dart';
import '../entities/wish_item_state.dart';
import '../entities/wish_planning_intent.dart';
import '../enums/preferred_time.dart';
import '../enums/wait_tolerance.dart';
import '../enums/wish_item_category.dart';

class WishPlanningIntentResolver {
  const WishPlanningIntentResolver();

  List<WishPlanningIntent> resolve({
    required Iterable<WishItem> items,
    required WishItemState Function(String itemId) stateFor,
  }) {
    final byFacility = <String, WishPlanningIntent>{};

    for (final item in items) {
      final state = stateFor(item.id);
      if (!state.selected || state.completed) continue;
      final repeatable = item.venueFacilityIds.length == 1 &&
          (item.category == WishItemCategory.attraction ||
              item.category == WishItemCategory.greeting);
      final targetCount = repeatable ? state.targetCount.clamp(1, 5) : 1;

      for (final facilityId in item.venueFacilityIds.where((id) => id.isNotEmpty)) {
        final candidate = WishPlanningIntent(
          facilityId: facilityId,
          importance: state.importance,
          targetCount: targetCount,
          preferredTime: state.preferredTime,
          waitTolerance: state.waitTolerance,
        );
        final current = byFacility[facilityId];
        if (current == null) {
          byFacility[facilityId] = candidate;
          continue;
        }

        final candidateRank = candidate.planPriority.value;
        final currentRank = current.planPriority.value;
        byFacility[facilityId] = WishPlanningIntent(
          facilityId: facilityId,
          importance: candidateRank > currentRank
              ? candidate.importance
              : current.importance,
          targetCount: candidate.targetCount > current.targetCount
              ? candidate.targetCount
              : current.targetCount,
          preferredTime: _mergePreferredTime(
            current: current.preferredTime,
            candidate: candidate.preferredTime,
            preferCandidate: candidateRank > currentRank,
          ),
          waitTolerance: _mergeWaitTolerance(
            current: current.waitTolerance,
            candidate: candidate.waitTolerance,
            preferCandidate: candidateRank > currentRank,
          ),
        );
      }
    }

    return List<WishPlanningIntent>.unmodifiable(byFacility.values);
  }

  PreferredTime _mergePreferredTime({
    required PreferredTime current,
    required PreferredTime candidate,
    required bool preferCandidate,
  }) {
    // A higher-priority wish owns a conflicting explicit time, but its
    // default `anytime` must not erase a specific condition already attached
    // to the same facility by another wish item.
    if (preferCandidate && candidate != PreferredTime.anytime) return candidate;
    if (current == PreferredTime.anytime && candidate != PreferredTime.anytime) {
      return candidate;
    }
    return current;
  }

  WaitTolerance _mergeWaitTolerance({
    required WaitTolerance current,
    required WaitTolerance candidate,
    required bool preferCandidate,
  }) {
    // As with preferred time, an unconstrained higher-priority wish must not
    // accidentally clear an explicit wait condition for the same facility.
    if (preferCandidate && candidate != WaitTolerance.any) return candidate;
    if (current == WaitTolerance.any && candidate != WaitTolerance.any) {
      return candidate;
    }
    return current;
  }
}
