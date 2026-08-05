import '../entities/dpa_strategy.dart';
import '../entities/plan_preference.dart';
import '../enums/facility_category.dart';
import 'dpa_strategy_engine.dart';
import 'wish_candidate_scoring_engine.dart';

class DpaAutoAllocationResult {
  const DpaAutoAllocationResult({required this.preferences, required this.selectedFacilityIds});
  final List<PlanPreference> preferences;
  final List<String> selectedFacilityIds;
}

class DpaAutoAllocator {
  const DpaAutoAllocator({this.strategyEngine = const DpaStrategyEngine()});
  final DpaStrategyEngine strategyEngine;

  DpaAutoAllocationResult allocate({
    required DpaStrategy strategy,
    required List<WishCandidateScore> candidates,
    required List<PlanPreference> preferences,
    int assumedDpaWaitMinutes = 15,
  }) {
    final selected = strategyEngine.select(
      strategy: strategy,
      candidates: candidates.where((item) => item.facility.supportsDpa).map((item) {
        final category = item.facility.category;
        return DpaCandidate(
          facilityId: item.facility.id,
          isAttraction: category == FacilityCategory.attraction,
          isShow: category == FacilityCategory.show || category == FacilityCategory.parade,
          priorityScore: (item.score / 100).clamp(0, 5).toDouble(),
          predictedWaitMinutes: item.predictedWaitMinutes,
          alternativeWaitMinutes: assumedDpaWaitMinutes,
        );
      }).toList(growable: false),
    );
    final ids = selected.map((item) => item.facilityId).toSet();
    final byId = {for (final item in preferences) item.facilityId: item};
    final updated = <PlanPreference>[];
    for (final candidate in candidates) {
      final existing = byId[candidate.facility.id] ?? PlanPreference.initial(facilityId: candidate.facility.id);
      updated.add(existing.copyWith(useDpa: ids.contains(candidate.facility.id)));
    }
    return DpaAutoAllocationResult(
      preferences: List.unmodifiable(updated),
      selectedFacilityIds: List.unmodifiable(ids),
    );
  }
}
