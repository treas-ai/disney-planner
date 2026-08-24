import 'package:disney_planner/domain/entities/ai_plan_result.dart';
import 'package:disney_planner/domain/entities/day_schedule.dart';
import 'package:disney_planner/domain/entities/dpa_strategy.dart';
import 'package:disney_planner/domain/entities/event_impact.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/entities/time_band_wait_profile.dart';
import 'package:disney_planner/domain/entities/trip_settings.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
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
      if (!facility.canAddToPlanAt(targetDate)) return false;
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
    final realistic = scoringEngine.selectRealisticCount(
      scored: ranked,
      availableMinutes: availableMinutes,
    );

    // selectRealisticCount is a capacity estimate, not the final day plan.
    // Keep explicitly high-priority wishes as reserve candidates so fixed
    // meals/shows do not leave large holes that could still fit a wish item.
    final preferenceById = {
      for (final preference in preferences) preference.facilityId: preference,
    };
    final planningIds = realistic.map((item) => item.facility.id).toSet();
    for (final candidate in ranked) {
      final preference = preferenceById[candidate.facility.id];
      if (preference != null && !preference.isExcluded && preference.priority.value >= 4) {
        planningIds.add(candidate.facility.id);
      }
    }
    final planningCandidates = ranked
        .where((item) => planningIds.contains(item.facility.id))
        .toList(growable: false);
    final planningFacilities = operationalFacilities
        .where((facility) => planningIds.contains(facility.id))
        .toList(growable: false);

    final attractionDpaMaxUses = settings.canUseDpa
        ? settings.attractionDpaMaxUses.clamp(0, 3).toInt()
        : 0;

    final optimizedPreferences = attractionDpaMaxUses > 0
        ? _optimizeAttractionDpaForWholeDay(
            settings: settings,
            facilities: planningFacilities,
            candidates: planningCandidates,
            preferences: preferences,
            waitProfiles: waitProfiles,
            eventImpacts: eventImpacts,
            morningScores: {
              for (final candidate in ranked)
                candidate.facility.id: candidate.firstMoveScore ?? candidate.score,
            },
            maxUses: attractionDpaMaxUses,
          )
        : _applyDpaSelection(preferences, const <String>{});

    final dpaIds = optimizedPreferences
        .where((item) => item.useDpa && planningIds.contains(item.facilityId))
        .map((item) => item.facilityId)
        .toList(growable: false);

    final schedule = scheduleEngine.generate(
      settings: settings,
      facilities: planningFacilities,
      preferences: optimizedPreferences,
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
      selectedCandidates: List.unmodifiable(planningCandidates),
      preferences: List.unmodifiable(optimizedPreferences),
      dpaFacilityIds: List.unmodifiable(dpaIds),
      generatedAt: DateTime.now(),
    );
  }

  List<PlanPreference> _optimizeAttractionDpaForWholeDay({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<WishCandidateScore> candidates,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required List<EventImpact> eventImpacts,
    required Map<String, double> morningScores,
    required int maxUses,
  }) {
    final eligibleIds = candidates
        .where((item) => item.facility.supportsDpa && item.facility.category.name == 'attraction')
        .map((item) => item.facility.id)
        .toList(growable: false);

    var selected = <String>{};
    var bestPreferences = _applyDpaSelection(preferences, selected);
    var bestScore = _scoreWholeDay(
      schedule: scheduleEngine.generate(
        settings: settings,
        facilities: facilities,
        preferences: bestPreferences,
        eventImpacts: eventImpacts,
        waitProfiles: waitProfiles,
        morningScores: morningScores,
      ),
      facilities: facilities,
      preferences: bestPreferences,
      dpaUses: 0,
    );

    for (var use = 0; use < maxUses; use++) {
      String? bestNextId;
      List<PlanPreference>? bestNextPreferences;
      var bestNextScore = bestScore;

      for (final id in eligibleIds) {
        if (selected.contains(id)) continue;
        final trialIds = {...selected, id};
        final trialPreferences = _applyDpaSelection(preferences, trialIds);
        final trialSchedule = scheduleEngine.generate(
          settings: settings,
          facilities: facilities,
          preferences: trialPreferences,
          eventImpacts: eventImpacts,
          waitProfiles: waitProfiles,
          morningScores: morningScores,
        );
        final trialScore = _scoreWholeDay(
          schedule: trialSchedule,
          facilities: facilities,
          preferences: trialPreferences,
          dpaUses: trialIds.length,
        );
        if (trialScore > bestNextScore) {
          bestNextScore = trialScore;
          bestNextId = id;
          bestNextPreferences = trialPreferences;
        }
      }

      // "maximum N" is a ceiling. Do not spend another DPA unless the
      // resulting whole-day plan is actually better.
      if (bestNextId == null || bestNextPreferences == null) break;
      selected = {...selected, bestNextId};
      bestPreferences = bestNextPreferences;
      bestScore = bestNextScore;
    }
    return bestPreferences;
  }

  List<PlanPreference> _applyDpaSelection(
    List<PlanPreference> preferences,
    Set<String> selectedIds,
  ) {
    return preferences.map((preference) {
      final selected = selectedIds.contains(preference.facilityId);
      return preference.copyWith(
        useDpa: selected,
        accessMethod: selected
            ? FacilityAccessMethod.dpa
            : preference.accessMethod == FacilityAccessMethod.dpa
                ? FacilityAccessMethod.standby
                : preference.accessMethod,
      );
    }).toList(growable: false);
  }

  double _scoreWholeDay({
    required DaySchedule schedule,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required int dpaUses,
  }) {
    final facilityById = {for (final facility in facilities) facility.id: facility};
    final preferenceById = {for (final preference in preferences) preference.facilityId: preference};
    final scheduledIds = <String>{};
    var waitMinutes = 0;
    var preferenceValue = 0.0;

    for (final item in schedule.items) {
      final id = item.facilityId;
      if (id == null || !scheduledIds.add(id)) continue;
      waitMinutes += item.estimatedWaitMinutes ?? 0;
      final facility = facilityById[id];
      final preference = preferenceById[id];
      if (facility != null && preference != null) {
        preferenceValue += preference.priority.value * 80.0;
      }
    }

    // Completing another wanted facility is worth more than shaving a few
    // minutes from one queue. Queue reduction then breaks ties. A small DPA
    // cost prevents "maximum N" from becoming "always use N".
    return scheduledIds.length * 600.0 +
        preferenceValue -
        waitMinutes * 2.0 -
        dpaUses * 25.0;
  }

  int _availableMinutes(TripSettings settings) {
    final entry = settings.entryTimeHour * 60 + settings.entryTimeMinute;
    final exit = settings.exitTimeHour * 60 + settings.exitTimeMinute;
    return (exit - entry).clamp(0, 24 * 60);
  }
}
