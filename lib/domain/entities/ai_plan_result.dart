import 'day_schedule.dart';
import 'plan_preference.dart';
import '../services/wish_candidate_scoring_engine.dart';

class AiPlanResult {
  const AiPlanResult({
    required this.schedule,
    required this.rankedCandidates,
    required this.selectedCandidates,
    required this.preferences,
    required this.dpaFacilityIds,
    required this.generatedAt,
  });

  final DaySchedule schedule;
  final List<WishCandidateScore> rankedCandidates;
  final List<WishCandidateScore> selectedCandidates;
  final List<PlanPreference> preferences;
  final List<String> dpaFacilityIds;
  final DateTime generatedAt;
}
