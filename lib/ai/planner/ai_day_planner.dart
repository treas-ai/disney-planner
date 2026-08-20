import 'package:disney_planner/domain/entities/ai_plan_result.dart';
import 'package:disney_planner/domain/entities/dpa_strategy.dart';
import 'package:disney_planner/domain/entities/event_impact.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/dpa_auto_allocator.dart';
import 'package:disney_planner/domain/services/schedule_engine.dart';
import 'package:disney_planner/domain/services/wish_candidate_scoring_engine.dart';

class AiDayPlanner {
  const AiDayPlanner({
    this.scoringEngine = const WishCandidateScoringEngine(),
    this.dpaAllocator = const DpaAutoAllocator(),
    this.scheduleEngine = const ScheduleEngine(),
  });

  final WishCandidateScoringEngine scoringEngine;
  final DpaAutoAllocator dpaAllocator;
  final ScheduleEngine scheduleEngine;

  AiPlanResult generate({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required DpaStrategy dpaStrategy,
    List<EventImpact> eventImpacts = const [],
    WaitTimeBand targetBand = WaitTimeBand.afterLunch,
  }) {
    final availableMinutes = _availableMinutes(settings);
    final targetDate = settings.visitDate ?? DateTime.now();
    final operationalFacilities = facilities.where((facility) {
      if (!facility.canAddToPlanAt(targetDate)) {
        return false;
      }

      // 営業時間未登録は「休止」ではないため候補から消さない。

      return true;
    }).toList(growable: false);

    final ranked = scoringEngine.score(
      facilities: operationalFacilities,
      preferences: preferences,
      waitProfiles: waitProfiles,
      availableMinutes: availableMinutes,
      targetBand: targetBand,
      targetDate: targetDate,
      hasHappyEntry: settings.hasHappyEntry,
    );
    final selected = scoringEngine.selectRealisticCount(
      scored: ranked,
      availableMinutes: availableMinutes,
    );

    final allocation = settings.canUseDpa
        ? dpaAllocator.allocate(
            strategy: dpaStrategy,
            candidates: selected,
            preferences: preferences,
          )
        : DpaAutoAllocationResult(
            preferences: List.unmodifiable(preferences),
            selectedFacilityIds: const [],
          );

    final selectedIds = selected.map((item) => item.facility.id).toSet();
    final selectedFacilities = operationalFacilities
        .where((facility) => selectedIds.contains(facility.id))
        .toList(growable: false);

    final schedule = scheduleEngine.generate(
      settings: settings,
      facilities: selectedFacilities,
      preferences: allocation.preferences,
      eventImpacts: eventImpacts,
      waitProfiles: waitProfiles,
      morningScores: {
        for (final candidate in ranked)
          candidate.facility.id: candidate.firstMoveScore ?? candidate.score,
      },
    );

    return AiPlanResult(
      schedule: schedule,
      rankedCandidates: List.unmodifiable(ranked),
      selectedCandidates: List.unmodifiable(selected),
      preferences: allocation.preferences,
      dpaFacilityIds: allocation.selectedFacilityIds,
      generatedAt: DateTime.now(),
    );
  }


  int _availableMinutes(TripSettings settings) {
    final entry = settings.entryTimeHour * 60 + settings.entryTimeMinute;
    final exit = settings.exitTimeHour * 60 + settings.exitTimeMinute;
    return (exit - entry).clamp(0, 24 * 60);
  }
}
