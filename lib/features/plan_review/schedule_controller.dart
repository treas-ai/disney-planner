import '../../data/repositories/crowd_factor_repository_impl.dart';
import '../../data/repositories/local_greeting_wait_planning_repository.dart';
import '../../data/repositories/local_vacation_package_unlimited_ride_repository.dart';
import '../../domain/services/wish_candidate_scoring_engine.dart';
import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/area_connection.dart';
import '../../domain/entities/facility_location.dart';
import '../../domain/entities/greeting_wait_planning_value.dart';
import '../../domain/entities/dpa_strategy.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/official_performance_opportunity.dart';
import '../../domain/entities/performance_time_option.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/entities/time_band_wait_profile.dart';
import '../../domain/entities/wait_time_range.dart';
import '../../domain/entities/schedule_validation_issue.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/schedule_item_type.dart';
import '../../domain/enums/wait_time_band.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/enums/dpa_strategy_type.dart';
import '../../data/local/local_performance_schedule_repository.dart';
import '../../domain/services/official_performance_preference_resolver.dart';
import '../../domain/services/dpa_auto_allocator.dart';
import '../../domain/services/free_time_improvement_scoring_service.dart';
import '../../domain/services/disney_expert_recommendation_service.dart';
import '../../domain/services/schedule_engine.dart';
import '../../domain/services/schedule_validator.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;
  final ScheduleEngine _scheduleEngine = const ScheduleEngine();
  final DpaAutoAllocator _dpaAutoAllocator = const DpaAutoAllocator();
  final ScheduleValidator _scheduleValidator = const ScheduleValidator();
  final FreeTimeImprovementScoringService _freeTimeScoringService =
      const FreeTimeImprovementScoringService();
  List<PlanPreference>? _generatedPreferences;
  final LocalPerformanceScheduleRepository _performanceScheduleRepository =
      LocalPerformanceScheduleRepository();
  late final OfficialPerformancePreferenceResolver _performanceResolver =
      OfficialPerformancePreferenceResolver(
        repository: _performanceScheduleRepository,
      );

  bool isLoading = false;
  String? errorMessage;

  DaySchedule? get schedule {
    return _appState.daySchedule;
  }

  List<PlanPreference> get preferencesForExport =>
      List<PlanPreference>.unmodifiable(
        _generatedPreferences ?? _appState.planPreferences,
      );

  String get selectedParkId {
    return _appState.tripSettings.parkId;
  }

  String get selectedParkName {
    return switch (selectedParkId) {
      'tokyo_disneyland' => '東京ディズニーランド',
      'tokyo_disneysea' => '東京ディズニーシー',
      _ => selectedParkId,
    };
  }

  IconData get selectedParkIcon {
    return switch (selectedParkId) {
      'tokyo_disneyland' => Icons.castle_outlined,
      'tokyo_disneysea' => Icons.water_outlined,
      _ => Icons.park_outlined,
    };
  }

  List<Facility> get selectedFacilitiesForCurrentPark {
    return List<Facility>.unmodifiable(
      _appState.selectedFacilities
          .where((facility) => facility.parkId == selectedParkId)
          .toList(growable: false),
    );
  }

  int get selectedFacilityCount {
    return selectedFacilitiesForCurrentPark.length;
  }

  List<Facility> get unavailableSelectedFacilities {
    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    return List<Facility>.unmodifiable(
      selectedFacilitiesForCurrentPark
          .where((facility) => !facility.canAddToPlanAt(targetDate))
          .toList(growable: false),
    );
  }

  int get unavailableSelectedFacilityCount {
    return unavailableSelectedFacilities.length;
  }

  bool get hasUnavailableSelectedFacilities {
    return unavailableSelectedFacilities.isNotEmpty;
  }

  bool get canGenerateSchedule {
    return selectedFacilitiesForCurrentPark.isNotEmpty;
  }

  bool get hasSchedule {
    return schedule != null;
  }

  bool get canUndo => _appState.canUndoScheduleChange;
  bool get canRedo => _appState.canRedoScheduleChange;
  int get historyCount => _appState.scheduleHistoryCount;

  List<ScheduleValidationIssue> get validationIssues {
    final current = schedule;
    if (current == null) {
      return const [];
    }
    return _scheduleValidator.validate(
      schedule: current,
      settings: _appState.tripSettings,
      preferences: _appState.planPreferences,
    );
  }

  void undoScheduleChange() => _appState.undoLastScheduleChange();
  void redoScheduleChange() => _appState.redoLastScheduleChange();

  bool get scheduleMatchesSelectedPark {
    final currentSchedule = schedule;

    if (currentSchedule == null) {
      return true;
    }

    return currentSchedule.parkId == selectedParkId;
  }

  bool get hasStaleSchedule {
    return schedule != null && !scheduleMatchesSelectedPark;
  }

  Facility? facilityById(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    for (final facility in _appState.selectedFacilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }

  PlanPreference? preferenceByFacilityId(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    return _appState.getPreference(facilityId);
  }

  List<String> get fixedTimeConflicts {
    final byTime = <String, List<String>>{};
    for (final facility in selectedFacilitiesForCurrentPark) {
      final preference = _appState.getPreference(facility.id);
      if (preference == null ||
          preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
        continue;
      }
      final time = preference.preferredPerformanceTime.trim().isNotEmpty
          ? preference.preferredPerformanceTime.trim()
          : preference.reservationTime.trim().isNotEmpty
          ? preference.reservationTime.trim()
          : preference.scheduledAccessTime.trim();
      if (time.isEmpty) continue;
      byTime.putIfAbsent(time, () => <String>[]).add(facility.name);
    }
    return [
      for (final entry in byTime.entries)
        if (entry.value.length > 1) '${entry.key}：${entry.value.join('、')}',
    ];
  }

  Future<void> generateSchedule({
    List<ScheduleItem> additionalManualFixedItems = const <ScheduleItem>[],
    bool preserveManualFixedItems = true,
  }) async {
    if (!canGenerateSchedule) {
      errorMessage =
          '現在のパークでは施設が選択されていません。'
          'プラン編集画面から行きたい施設を追加してください。';

      notifyListeners();

      return;
    }

    final conflicts = fixedTimeConflicts;
    if (conflicts.isNotEmpty) {
      errorMessage = '固定予定が競合しています。時刻を変更してください。\n${conflicts.join('\n')}';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
      final availableFacilities = selectedFacilitiesForCurrentPark
          .where((facility) => facility.canAddToPlanAt(targetDate))
          .toList(growable: false);

      if (availableFacilities.isEmpty) {
        errorMessage =
            '営業中の施設が選択されていません。'
            '休止中施設の選択を解除してください。';

        return;
      }

      final selectedFacilityIds = availableFacilities
          .map((facility) => facility.id)
          .toSet();

      final selectedPreferences = _appState.planPreferences
          .where((preference) {
            return selectedFacilityIds.contains(preference.facilityId);
          })
          .toList(growable: false);

      final settings = _appState.tripSettings;
      final manualFixedItems =
          preserveManualFixedItems &&
                  settings.usesVacationPackage &&
                  settings.hasUnlimitedAttractionRides
              ? <ScheduleItem>[
                  ..._manualRepeatItemsForDate(targetDate),
                  ...additionalManualFixedItems,
                ]
              : <ScheduleItem>[];
      final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
              settings.hasUnlimitedAttractionRides
          ? await const LocalVacationPackageUnlimitedRideRepository()
              .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
          : <String, int>{};
      final preferences = await _performanceResolver.resolve(
        parkId: selectedParkId,
        date: targetDate,
        entryMinutes: settings.entryTimeHour * 60 + settings.entryTimeMinute,
        exitMinutes: settings.exitTimeHour * 60 + settings.exitTimeMinute,
        facilities: availableFacilities,
        preferences: selectedPreferences,
      );

      for (final preference in preferences) {
        final current = _appState.getPreference(preference.facilityId);
        if (current == null ||
            current.preferredPerformanceTime ==
                preference.preferredPerformanceTime) {
          continue;
        }
        _appState.updatePreferenceSelectedPerformance(
          facilityId: preference.facilityId,
          performanceIndex: preference.selectedPerformanceIndex,
          startTime: preference.preferredPerformanceTime,
        );
      }

      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: selectedParkId);

      final waitProfiles = await const CrowdFactorRepositoryImpl()
          .loadWaitProfiles(parkId: selectedParkId);
      final crowdFactors = await const CrowdFactorRepositoryImpl()
          .loadCrowdFactors(parkId: selectedParkId);
      final greetingWaitPlanning =
          await const LocalGreetingWaitPlanningRepository().load(
            parkId: selectedParkId,
            targetDate: targetDate,
            facilities: availableFacilities,
            crowdFactors: crowdFactors,
          );
      final expertProfiles = await ServiceLocator.expertRecommendationRepository
          .loadProfiles(parkId: selectedParkId);
      final availableMinutes =
          (settings.exitTimeHour * 60 + settings.exitTimeMinute) -
          (settings.entryTimeHour * 60 + settings.entryTimeMinute);
      final morningRanking = const WishCandidateScoringEngine().score(
        facilities: availableFacilities,
        preferences: preferences,
        waitProfiles: waitProfiles,
        availableMinutes: availableMinutes,
        targetDate: targetDate,
        hasHappyEntry: settings.hasHappyEntry,
        expertProfiles: expertProfiles,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );

      var generatedPreferences = preferences;
      if (settings.canUseDpa && settings.attractionDpaMaxUses > 0) {
        final allocation = _dpaAutoAllocator.allocate(
          strategy: DpaStrategy(
            type: DpaStrategyType.highCongestionOnly,
            maxUses: settings.attractionDpaMaxUses.clamp(0, 3).toInt(),
          ),
          candidates: morningRanking
              .where(
                (candidate) =>
                    !unlimitedRideBufferMinutes.containsKey(candidate.facility.id),
              )
              .toList(growable: false),
          preferences: preferences,
        );
        generatedPreferences = allocation.preferences;
      }
      _generatedPreferences = List<PlanPreference>.unmodifiable(
        generatedPreferences,
      );

      final allParkFacilities = await ServiceLocator.facilityRepository
          .getFacilitiesByParkId(selectedParkId);
      final allParkFacilityById = {
        for (final facility in allParkFacilities) facility.id: facility,
      };
      final officialOptions = await _performanceScheduleRepository
          .findParkOptions(
            parkId: selectedParkId,
            date: targetDate,
          );
      final officialPerformanceOpportunities =
          <OfficialPerformanceOpportunity>[];
      for (final option in officialOptions) {
        final facility = allParkFacilityById[option.facilityId];
        if (facility == null ||
            (facility.category != FacilityCategory.show &&
                facility.category != FacilityCategory.parade)) {
          continue;
        }
        final startMinutes = _parseTimeMinutes(option.startTime);
        if (startMinutes == null) continue;
        officialPerformanceOpportunities.add(
          OfficialPerformanceOpportunity(
            facilityId: facility.id,
            name: facility.name,
            startMinutes: startMinutes,
            endMinutes: startMinutes + facility.durationMinutes,
            requiresEntryRequest: facility.requiresEntryRequest,
            supportsDpa: facility.supportsDpa,
            isSelected: selectedFacilityIds.contains(facility.id),
          ),
        );
      }

      final areaConnections = await ServiceLocator.movementRepository
          .loadAreaConnections(parkId: selectedParkId);
      final facilityLocations = await ServiceLocator.movementRepository
          .loadFacilityLocations(parkId: selectedParkId);

      final generatedSchedule = _scheduleEngine.generate(
        settings: _appState.tripSettings,
        facilities: availableFacilities,
        preferences: generatedPreferences,
        eventImpacts: eventImpacts,
        waitProfiles: waitProfiles,
        morningScores: {
          for (final candidate in morningRanking)
            candidate.facility.id:
                candidate.firstMoveScore ?? candidate.score,
        },
        officialPerformanceOpportunities:
            officialPerformanceOpportunities,
        areaConnections: areaConnections,
        facilityLocations: facilityLocations,
        expertProfiles: expertProfiles,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
        manualFixedItems: manualFixedItems,
      );

      _appState.updateDaySchedule(generatedSchedule);
    } catch (error, stackTrace) {
      debugPrint('スケジュール生成に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage =
          'スケジュール生成に失敗しました。'
          '設定と選択施設を確認して、もう一度お試しください。';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<List<PerformancePlanChoice>> loadPerformancePlanChoices() async {
    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final facilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final facilityById = {
      for (final facility in facilities)
        if (facility.category == FacilityCategory.show ||
            facility.category == FacilityCategory.parade)
          facility.id: facility,
    };
    final options = await _performanceScheduleRepository.findParkOptions(
      parkId: selectedParkId,
      date: targetDate,
    );

    final choices = <PerformancePlanChoice>[];
    for (final option in options) {
      final facility = facilityById[option.facilityId];
      if (facility == null || !facility.canAddToPlanAt(targetDate)) {
        continue;
      }
      choices.add(PerformancePlanChoice(facility: facility, option: option));
    }

    choices.sort((left, right) {
      final byTime = left.option.startTime.compareTo(right.option.startTime);
      if (byTime != 0) return byTime;
      return left.facility.name.compareTo(right.facility.name);
    });
    return List<PerformancePlanChoice>.unmodifiable(choices);
  }

  Future<void> addPerformanceToPlan(PerformancePlanChoice choice) async {
    if (!_appState.isFacilitySelected(choice.facility.id)) {
      _appState.addFacility(choice.facility);
    }

    _appState.updatePreferenceSelectedPerformance(
      facilityId: choice.facility.id,
      performanceIndex: choice.option.performanceIndex,
      startTime: choice.option.startTime,
    );

    await generateSchedule();
  }


  Future<List<FreeTimeImprovementChoice>> loadFreeTimeImprovementChoices(
    ScheduleItem freeTimeItem,
  ) async {
    final currentSchedule = schedule;
    if (currentSchedule == null ||
        freeTimeItem.type != ScheduleItemType.breakTime) {
      return const <FreeTimeImprovementChoice>[];
    }

    final gapStart = freeTimeItem.startHour * 60 + freeTimeItem.startMinute;
    final gapEnd = freeTimeItem.endHour * 60 + freeTimeItem.endMinute;
    if (gapEnd - gapStart < 20) {
      return const <FreeTimeImprovementChoice>[];
    }

    final sortedItems = [...currentSchedule.items]
      ..sort((a, b) {
        final aStart = a.startHour * 60 + a.startMinute;
        final bStart = b.startHour * 60 + b.startMinute;
        return aStart.compareTo(bStart);
      });
    final index = sortedItems.indexWhere((item) => item.id == freeTimeItem.id);
    if (index < 0) {
      return const <FreeTimeImprovementChoice>[];
    }
    final previousItem = index > 0 ? sortedItems[index - 1] : null;
    final nextItem = index + 1 < sortedItems.length
        ? sortedItems[index + 1]
        : null;

    final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
    final settings = _appState.tripSettings;
    final allFacilities = await ServiceLocator.facilityRepository
        .getFacilitiesByParkId(selectedParkId);
    final facilityById = {
      for (final facility in allFacilities) facility.id: facility,
    };
    final locations = await ServiceLocator.movementRepository
        .loadFacilityLocations(parkId: selectedParkId);
    final locationById = {
      for (final location in locations) location.facilityId: location,
    };
    final connections = await ServiceLocator.movementRepository
        .loadAreaConnections(parkId: selectedParkId);
    final waitProfiles = await const CrowdFactorRepositoryImpl()
        .loadWaitProfiles(parkId: selectedParkId);
    final expertProfiles = await ServiceLocator.expertRecommendationRepository
        .loadProfiles(parkId: selectedParkId);
    final waitProfileById = {
      for (final profile in waitProfiles) profile.facilityId: profile,
    };
    final crowdFactors = await const CrowdFactorRepositoryImpl()
        .loadCrowdFactors(parkId: selectedParkId);
    final greetingWaitPlanning =
        await const LocalGreetingWaitPlanningRepository().load(
          parkId: selectedParkId,
          targetDate: targetDate,
          facilities: allFacilities,
          crowdFactors: crowdFactors,
        );
    final unlimitedRideBufferMinutes = settings.usesVacationPackage &&
            settings.hasUnlimitedAttractionRides
        ? await const LocalVacationPackageUnlimitedRideRepository()
            .loadPriorityAccessBufferMinutes(parkId: selectedParkId)
        : <String, int>{};

    final previousAreaId = _scheduleItemExitAreaId(
      previousItem,
      facilityById: facilityById,
      locationById: locationById,
    );
    final nextAreaId = _scheduleItemEntryAreaId(
      nextItem,
      facilityById: facilityById,
      locationById: locationById,
    );
    final scheduledFacilityCounts = <String, int>{};
    for (final item in currentSchedule.items) {
      final facilityId = item.facilityId;
      if (facilityId == null || facilityId.isEmpty) continue;
      scheduledFacilityCounts.update(
        facilityId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final choices = <FreeTimeImprovementChoice>[];
    for (final facility in allFacilities) {
      final scheduledCount = scheduledFacilityCounts[facility.id] ?? 0;
      final isManualRepeatCandidate =
          scheduledCount > 0 &&
          facility.category == FacilityCategory.attraction &&
          unlimitedRideBufferMinutes.containsKey(facility.id);

      if (!facility.canAddToPlanAt(targetDate) ||
          (scheduledCount > 0 && !isManualRepeatCandidate) ||
          facility.category == FacilityCategory.show ||
          facility.category == FacilityCategory.parade ||
          facility.category == FacilityCategory.restaurant ||
          facility.category == FacilityCategory.service ||
          facility.requiresEntryRequest ||
          facility.requiresReservation) {
        continue;
      }
      if (facility.category != FacilityCategory.attraction &&
          facility.category != FacilityCategory.greeting) {
        continue;
      }

      final entryAreaId = locationById[facility.id]?.areaId ?? facility.areaId;
      final exitAreaId =
          locationById[facility.id]?.effectiveExitAreaId ?? facility.areaId;
      final movementIn = previousItem?.facilityId == facility.id
          ? 0
          : previousAreaId == null
              ? 0
              : _movementMinutes(
                  fromAreaId: previousAreaId,
                  toAreaId: entryAreaId,
                  connections: connections,
                );
      final movementOut = nextItem?.facilityId == facility.id
          ? 0
          : nextAreaId == null
              ? 0
              : _movementMinutes(
                  fromAreaId: exitAreaId,
                  toAreaId: nextAreaId,
                  connections: connections,
                );

      var plannedStart = gapStart + movementIn;
      var wait = _freeTimeWaitEstimate(
        facility: facility,
        scheduledStartMinutes: plannedStart,
        profile: waitProfileById[facility.id],
        greetingWaitPlanning: greetingWaitPlanning[facility.id],
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );
      var plannedDuration = facility.durationMinutes + wait.minutes;

      final operatingStart = _earliestOperatingStart(
        facility: facility,
        targetDate: targetDate,
        requestedStartMinutes: plannedStart,
        durationMinutes: plannedDuration,
        latestEndMinutes: gapEnd - movementOut,
      );
      if (operatingStart == null) {
        continue;
      }
      plannedStart = operatingStart;
      wait = _freeTimeWaitEstimate(
        facility: facility,
        scheduledStartMinutes: plannedStart,
        profile: waitProfileById[facility.id],
        greetingWaitPlanning: greetingWaitPlanning[facility.id],
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );
      plannedDuration = facility.durationMinutes + wait.minutes;
      final verifiedOperatingStart = _earliestOperatingStart(
        facility: facility,
        targetDate: targetDate,
        requestedStartMinutes: plannedStart,
        durationMinutes: plannedDuration,
        latestEndMinutes: gapEnd - movementOut,
      );
      if (verifiedOperatingStart == null ||
          verifiedOperatingStart != plannedStart) {
        continue;
      }
      final plannedEnd = plannedStart + plannedDuration;
      if (plannedEnd + movementOut > gapEnd) {
        continue;
      }

      final alreadySelected = _appState.isFacilitySelected(facility.id);
      final existingPreference = _appState.getPreference(facility.id);
      if (!isManualRepeatCandidate &&
          alreadySelected &&
          existingPreference != null &&
          existingPreference.accessMethod != FacilityAccessMethod.standby) {
        continue;
      }
      final totalUsed = movementIn + plannedDuration + movementOut;
      final slack = (gapEnd - gapStart) - totalUsed;
      final effectivePriority =
          existingPreference?.priority.value ?? facility.priority.value;
      final expert = const DisneyExpertRecommendationService().evaluate(
        facility: facility,
        targetDate: targetDate,
        profiles: expertProfiles,
        preference: existingPreference,
        waitProfiles: waitProfiles,
      );
      final score = _freeTimeScoringService.scoreFacility(
        priorityValue: effectivePriority,
        plannedDurationMinutes: plannedDuration,
        movementInMinutes: movementIn,
        movementOutMinutes: movementOut,
        fitSlackMinutes: slack,
        isWishlisted: alreadySelected,
        samePreviousArea: previousAreaId == entryAreaId,
        sameNextArea: nextAreaId == exitAreaId,
        isGreeting: facility.category == FacilityCategory.greeting,
        expertScore: expert.score,
        estimatedWaitMinutes: wait.minutes,
        gapMinutes: gapEnd - gapStart,
      );

      choices.add(
        isManualRepeatCandidate
            ? FreeTimeImprovementChoice.repeatAttraction(
                facility: facility,
                plannedStartMinutes: plannedStart,
                plannedEndMinutes: plannedEnd,
                estimatedWaitMinutes: wait.minutes,
                waitSource: wait.source,
                movementInMinutes: movementIn,
                movementOutMinutes: movementOut,
                fitSlackMinutes: slack,
                score: score,
                repeatNumber: scheduledCount + 1,
                expertScore: expert.score,
                expertReason: expert.reason,
              )
            : FreeTimeImprovementChoice.facility(
                facility: facility,
                plannedStartMinutes: plannedStart,
                plannedEndMinutes: plannedEnd,
                estimatedWaitMinutes: wait.minutes,
                waitSource: wait.source,
                movementInMinutes: movementIn,
                movementOutMinutes: movementOut,
                fitSlackMinutes: slack,
                score: score,
                alreadySelected: alreadySelected,
                expertScore: expert.score,
                expertReason: expert.reason,
              ),
      );
    }

    final performanceOptions = await _performanceScheduleRepository
        .findParkOptions(parkId: selectedParkId, date: targetDate);
    for (final option in performanceOptions) {
      final facility = facilityById[option.facilityId];
      if (facility == null ||
          !facility.canAddToPlanAt(targetDate) ||
          (facility.category != FacilityCategory.show &&
              facility.category != FacilityCategory.parade)) {
        continue;
      }
      final start = _parseTimeMinutes(option.startTime);
      if (start == null) continue;
      final end = start + facility.durationMinutes;
      if (start < gapStart || end > gapEnd) continue;
      final alreadyScheduled = currentSchedule.items.any(
        (item) =>
            item.facilityId == facility.id && item.startTimeLabel == option.startTime,
      );
      if (alreadyScheduled) continue;

      final entryAreaId = locationById[facility.id]?.areaId ?? facility.areaId;
      final exitAreaId =
          locationById[facility.id]?.effectiveExitAreaId ?? facility.areaId;
      final movementIn = previousAreaId == null
          ? 0
          : _movementMinutes(
              fromAreaId: previousAreaId,
              toAreaId: entryAreaId,
              connections: connections,
            );
      final movementOut = nextAreaId == null
          ? 0
          : _movementMinutes(
              fromAreaId: exitAreaId,
              toAreaId: nextAreaId,
              connections: connections,
            );
      const preparationMinutes = 15;
      if (gapStart + movementIn + preparationMinutes > start ||
          end + movementOut > gapEnd) {
        continue;
      }

      final fitSlack = (gapEnd - gapStart) -
          (movementIn + preparationMinutes + facility.durationMinutes + movementOut);
      var score = facility.priority.value * 26.0;
      score -= (movementIn + movementOut) * 0.5;
      score -= fitSlack.clamp(0, 180) * 0.02;
      if (!facility.requiresEntryRequest) score += 8;
      choices.add(
        FreeTimeImprovementChoice.performance(
          facility: facility,
          option: option,
          plannedStartMinutes: start,
          plannedEndMinutes: end,
          movementInMinutes: movementIn,
          movementOutMinutes: movementOut,
          preparationMinutes: preparationMinutes,
          fitSlackMinutes: fitSlack,
          score: score,
        ),
      );
    }

    choices.sort((left, right) {
      final scoreCompare = right.score.compareTo(left.score);
      if (scoreCompare != 0) return scoreCompare;
      return left.plannedStartMinutes.compareTo(right.plannedStartMinutes);
    });
    return List<FreeTimeImprovementChoice>.unmodifiable(choices);
  }

  Future<List<FreeTimeImprovementChoice>> loadRepeatRideChoicesForFacility(
    String facilityId, {
    int? minimumStartMinutes,
  }) async {
    final currentSchedule = schedule;
    if (currentSchedule == null || facilityId.trim().isEmpty) {
      return const <FreeTimeImprovementChoice>[];
    }

    final gaps = currentSchedule.items
        .where((item) {
          if (item.type != ScheduleItemType.breakTime) return false;
          final start = item.startHour * 60 + item.startMinute;
          final end = item.endHour * 60 + item.endMinute;
          if (end - start < 20) return false;
          if (minimumStartMinutes != null && end <= minimumStartMinutes) {
            return false;
          }
          return true;
        })
        .toList(growable: false)
      ..sort((left, right) {
        final leftStart = left.startHour * 60 + left.startMinute;
        final rightStart = right.startHour * 60 + right.startMinute;
        return leftStart.compareTo(rightStart);
      });

    final repeatChoices = <FreeTimeImprovementChoice>[];
    for (final gap in gaps) {
      final gapStart = gap.startHour * 60 + gap.startMinute;
      final gapEnd = gap.endHour * 60 + gap.endMinute;
      var evaluationGap = gap;
      if (minimumStartMinutes != null &&
          gapStart < minimumStartMinutes &&
          minimumStartMinutes < gapEnd) {
        evaluationGap = ScheduleItem(
          id: gap.id,
          title: gap.title,
          type: ScheduleItemType.breakTime,
          startHour: minimumStartMinutes ~/ 60,
          startMinute: minimumStartMinutes % 60,
          endHour: gap.endHour,
          endMinute: gap.endMinute,
          reason: gap.reason,
          note: gap.note,
        );
      }

      final choices = await loadFreeTimeImprovementChoices(evaluationGap);
      for (final choice in choices) {
        if (choice.kind != FreeTimeImprovementKind.repeatAttraction ||
            choice.facility.id != facilityId) {
          continue;
        }
        if (minimumStartMinutes != null &&
            choice.plannedStartMinutes < minimumStartMinutes) {
          continue;
        }
        repeatChoices.add(choice);
      }
    }

    repeatChoices.sort((left, right) {
      final byStart = left.plannedStartMinutes.compareTo(
        right.plannedStartMinutes,
      );
      if (byStart != 0) return byStart;
      return right.score.compareTo(left.score);
    });

    return List<FreeTimeImprovementChoice>.unmodifiable(repeatChoices);
  }

  Future<void> applyFreeTimeImprovement(
    FreeTimeImprovementChoice choice,
  ) async {
    if (choice.kind == FreeTimeImprovementKind.performance) {
      final option = choice.performanceOption;
      if (option == null) return;
      await addPerformanceToPlan(
        PerformancePlanChoice(facility: choice.facility, option: option),
      );
      return;
    }

    if (choice.kind == FreeTimeImprovementKind.repeatAttraction) {
      final targetDate = _appState.tripSettings.visitDate ?? DateTime.now();
      final repeatNumber = choice.repeatNumber ?? 2;
      final item = ScheduleItem(
        id:
            'manual_repeat_${_dateToken(targetDate)}_${choice.facility.id}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        title: '${choice.facility.name}（$repeatNumber回目）',
        type: ScheduleItemType.facility,
        startHour: choice.plannedStartMinutes ~/ 60,
        startMinute: choice.plannedStartMinutes % 60,
        endHour: choice.plannedEndMinutes ~/ 60,
        endMinute: choice.plannedEndMinutes % 60,
        facilityId: choice.facility.id,
        reason:
            '空き時間改善からユーザーが明示的に追加した$repeatNumber回目の利用です。'
            'Disney Plannerが自動で再乗車を追加したものではありません。'
            '既存の予定は動かさず、この空き時間へ局所挿入しています。',
        note:
            'ユーザーが手動追加した再乗車です。不要になった場合はプランを元に戻すか再編集できます。',
        estimatedWaitMinutes: choice.estimatedWaitMinutes,
        experienceMinutes: choice.facility.durationMinutes,
        waitEstimateSource: _canonicalUnlimitedRideSource(choice),
      );
      if (!_insertFreeTimeItemLocally(item)) {
        errorMessage =
            '空き時間の状態が変わったため、この場所へ追加できませんでした。'
            'プランを確認してもう一度お試しください。';
        notifyListeners();
      }
      return;
    }

    final facility = choice.facility;
    if (!_appState.isFacilitySelected(facility.id)) {
      _appState.addFacility(facility);
    }
    _appState.updatePreferenceFixedTimeStatus(
      facilityId: facility.id,
      status: FixedTimeStatus.planned,
    );
    _appState.updatePreferenceScheduledAccessTime(
      facilityId: facility.id,
      value: _formatMinutes(choice.plannedStartMinutes),
    );
    _appState.updatePreferencePreferredTime(
      facilityId: facility.id,
      preferredTime: _preferredTimeForMinutes(choice.plannedStartMinutes),
    );
    final updatedPreference = _appState.getPreference(facility.id);
    final currentGeneratedPreferences = _generatedPreferences;
    if (updatedPreference != null && currentGeneratedPreferences != null) {
      _generatedPreferences = List<PlanPreference>.unmodifiable([
        for (final preference in currentGeneratedPreferences)
          if (preference.facilityId != facility.id) preference,
        updatedPreference,
      ]);
    }

    final item = ScheduleItem(
      id:
          'manual_free_time_${_dateToken(_appState.tripSettings.visitDate ?? DateTime.now())}_'
          '${facility.id}_${DateTime.now().microsecondsSinceEpoch}',
      title: facility.name,
      type: ScheduleItemType.facility,
      startHour: choice.plannedStartMinutes ~/ 60,
      startMinute: choice.plannedStartMinutes % 60,
      endHour: choice.plannedEndMinutes ~/ 60,
      endMinute: choice.plannedEndMinutes % 60,
      facilityId: facility.id,
      reason:
          '空き時間改善からユーザーが明示的に追加した予定です。'
          '既存の予定は動かさず、この空き時間へ局所挿入しています。',
      note: '空き時間改善で手動追加した予定です。',
      estimatedWaitMinutes: choice.estimatedWaitMinutes,
      experienceMinutes: facility.durationMinutes,
      waitEstimateSource: _canonicalUnlimitedRideSource(choice),
    );
    if (!_insertFreeTimeItemLocally(item)) {
      errorMessage =
          '空き時間の状態が変わったため、この場所へ追加できませんでした。'
          'プランを確認してもう一度お試しください。';
      notifyListeners();
    }
  }

  _FreeTimeWaitEstimate _freeTimeWaitEstimate({
    required Facility facility,
    required int scheduledStartMinutes,
    required TimeBandWaitProfile? profile,
    required GreetingWaitPlanningValue? greetingWaitPlanning,
    required Map<String, int> unlimitedRideBufferMinutes,
  }) {
    if (unlimitedRideBufferMinutes.containsKey(facility.id) &&
        facility.category == FacilityCategory.attraction) {
      final minutes = unlimitedRideBufferMinutes[facility.id] ?? 15;
      return _FreeTimeWaitEstimate(
        minutes: minutes,
        source:
            'バケーションパッケージ乗り放題（優先入口利用バッファ$minutes分・Disney Planner計画値）',
      );
    }
    if (facility.category == FacilityCategory.greeting &&
        greetingWaitPlanning != null) {
      return _FreeTimeWaitEstimate(
        minutes: greetingWaitPlanning.waitMinutes,
        source: greetingWaitPlanning.source,
      );
    }

    final band = _waitBandForMinutes(scheduledStartMinutes);
    final range = profile?.rangeFor(band);
    if (range != null &&
        range.typicalMinutes > 0 &&
        (range.sampleCount == null || range.sampleCount! >= 3)) {
      return _FreeTimeWaitEstimate(
        minutes: _ceilToFive(range.typicalMinutes),
        source: '収集済み待ち時間実績（${band.label}）',
      );
    }

    final nearest = _nearestReliableWait(profile, band);
    if (nearest != null) {
      return _FreeTimeWaitEstimate(
        minutes: _ceilToFive(nearest.typicalMinutes),
        source: '収集済み待ち時間実績（近接時間帯）',
      );
    }

    final fallback = switch (facility.priority.name) {
      'highest' => 60,
      'high' => 45,
      'medium' => 30,
      _ => 20,
    };
    return _FreeTimeWaitEstimate(
      minutes: fallback,
      source: '実績不足のため安全側計画値',
    );
  }

  WaitTimeRange? _nearestReliableWait(
    TimeBandWaitProfile? profile,
    WaitTimeBand targetBand,
  ) {
    if (profile == null) return null;
    const bands = <WaitTimeBand>[
      WaitTimeBand.afterOpening,
      WaitTimeBand.beforeLunch,
      WaitTimeBand.afterLunch,
      WaitTimeBand.aroundShows,
      WaitTimeBand.beforeDinner,
      WaitTimeBand.afterDinner,
      WaitTimeBand.beforeClosing,
    ];
    final targetIndex = bands.indexOf(targetBand);
    WaitTimeRange? best;
    var bestDistance = 999;
    for (var index = 0; index < bands.length; index++) {
      final range = profile.rangeFor(bands[index]);
      if (range == null ||
          range.typicalMinutes <= 0 ||
          (range.sampleCount != null && range.sampleCount! < 3)) {
        continue;
      }
      final distance = (index - targetIndex).abs();
      if (distance < bestDistance) {
        best = range;
        bestDistance = distance;
      }
    }
    return best;
  }

  int? _earliestOperatingStart({
    required Facility facility,
    required DateTime targetDate,
    required int requestedStartMinutes,
    required int durationMinutes,
    required int latestEndMinutes,
  }) {
    final windows = [...facility.operatingWindowsFor(targetDate)]
      ..sort((a, b) => a.open.compareTo(b.open));
    if (windows.isEmpty) {
      return requestedStartMinutes + durationMinutes <= latestEndMinutes
          ? requestedStartMinutes
          : null;
    }
    for (final window in windows) {
      final open = window.open.hour * 60 + window.open.minute;
      final close = window.close.hour * 60 + window.close.minute;
      final start = requestedStartMinutes > open ? requestedStartMinutes : open;
      if (start + durationMinutes <= close &&
          start + durationMinutes <= latestEndMinutes) {
        return start;
      }
    }
    return null;
  }

  int _movementMinutes({
    required String fromAreaId,
    required String toAreaId,
    required List<AreaConnection> connections,
  }) {
    if (fromAreaId == toAreaId) return 5;
    if (connections.isEmpty) return 15;
    final distances = <String, int>{fromAreaId: 0};
    final visited = <String>{};
    while (true) {
      String? current;
      var currentDistance = 1 << 30;
      for (final entry in distances.entries) {
        if (!visited.contains(entry.key) && entry.value < currentDistance) {
          current = entry.key;
          currentDistance = entry.value;
        }
      }
      if (current == null) return 15;
      if (current == toAreaId) return currentDistance;
      visited.add(current);
      for (final connection in connections) {
        String? next;
        if (connection.fromAreaId == current) {
          next = connection.toAreaId;
        } else if (connection.bidirectional && connection.toAreaId == current) {
          next = connection.fromAreaId;
        }
        if (next == null || connection.minutes <= 0) continue;
        final candidate = currentDistance + connection.minutes;
        if (candidate < (distances[next] ?? (1 << 30))) {
          distances[next] = candidate;
        }
      }
    }
  }

  String? _scheduleItemEntryAreaId(
    ScheduleItem? item, {
    required Map<String, Facility> facilityById,
    required Map<String, FacilityLocation> locationById,
  }) {
    final facilityId = item?.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    return locationById[facilityId]?.areaId ?? facilityById[facilityId]?.areaId;
  }

  String? _scheduleItemExitAreaId(
    ScheduleItem? item, {
    required Map<String, Facility> facilityById,
    required Map<String, FacilityLocation> locationById,
  }) {
    final facilityId = item?.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    return locationById[facilityId]?.effectiveExitAreaId ??
        facilityById[facilityId]?.areaId;
  }

  WaitTimeBand _waitBandForMinutes(int minutes) {
    if (minutes < 11 * 60) return WaitTimeBand.afterOpening;
    if (minutes < 12 * 60) return WaitTimeBand.beforeLunch;
    if (minutes < 15 * 60) return WaitTimeBand.afterLunch;
    if (minutes < 17 * 60) return WaitTimeBand.aroundShows;
    if (minutes < 18 * 60) return WaitTimeBand.beforeDinner;
    if (minutes < 20 * 60) return WaitTimeBand.afterDinner;
    return WaitTimeBand.beforeClosing;
  }

  PreferredTime _preferredTimeForMinutes(int minutes) {
    if (minutes < 12 * 60) return PreferredTime.morning;
    if (minutes < 17 * 60) return PreferredTime.afternoon;
    return PreferredTime.evening;
  }

  int _ceilToFive(int minutes) {
    if (minutes <= 0) return 0;
    return ((minutes + 4) ~/ 5) * 5;
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _canonicalUnlimitedRideSource(FreeTimeImprovementChoice choice) {
    final source = choice.waitSource?.trim();
    if (source == null || source.isEmpty) return source;
    if (choice.kind == FreeTimeImprovementKind.repeatAttraction ||
        source.startsWith('バケパ乗り放題') ||
        source.startsWith('バケーションパッケージ乗り放題')) {
      final minutes = choice.estimatedWaitMinutes ?? 15;
      return 'バケーションパッケージ乗り放題（優先入口利用バッファ$minutes分・Disney Planner計画値）';
    }
    return source;
  }

  bool _insertFreeTimeItemLocally(ScheduleItem insertedItem) {
    final currentSchedule = schedule;
    if (currentSchedule == null) return false;

    final insertedStart =
        insertedItem.startHour * 60 + insertedItem.startMinute;
    final insertedEnd = insertedItem.endHour * 60 + insertedItem.endMinute;
    if (insertedEnd <= insertedStart) return false;

    ScheduleItem? targetGap;
    for (final candidate in currentSchedule.items) {
      if (candidate.type != ScheduleItemType.breakTime) continue;
      final gapStart = candidate.startHour * 60 + candidate.startMinute;
      final gapEnd = candidate.endHour * 60 + candidate.endMinute;
      if (gapStart <= insertedStart && insertedEnd <= gapEnd) {
        targetGap = candidate;
        break;
      }
    }
    if (targetGap == null) return false;

    final gapStart = targetGap.startHour * 60 + targetGap.startMinute;
    final gapEnd = targetGap.endHour * 60 + targetGap.endMinute;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final updatedItems = <ScheduleItem>[
      for (final item in currentSchedule.items)
        if (item.id != targetGap.id) item,
      if (_shouldKeepFreeTimeSegment(gapStart, insertedStart))
        _freeTimeSegment(
          source: targetGap,
          id: '${targetGap.id}_before_$stamp',
          startMinutes: gapStart,
          endMinutes: insertedStart,
        ),
      insertedItem,
      if (_shouldKeepFreeTimeSegment(insertedEnd, gapEnd))
        _freeTimeSegment(
          source: targetGap,
          id: '${targetGap.id}_after_$stamp',
          startMinutes: insertedEnd,
          endMinutes: gapEnd,
        ),
    ]..sort((left, right) {
        final leftStart = left.startHour * 60 + left.startMinute;
        final rightStart = right.startHour * 60 + right.startMinute;
        if (leftStart != rightStart) return leftStart.compareTo(rightStart);
        final leftEnd = left.endHour * 60 + left.endMinute;
        final rightEnd = right.endHour * 60 + right.endMinute;
        return leftEnd.compareTo(rightEnd);
      });

    _appState.updateDaySchedule(
      DaySchedule(
        id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
        parkId: currentSchedule.parkId,
        items: List<ScheduleItem>.unmodifiable(updatedItems),
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  bool _shouldKeepFreeTimeSegment(int startMinutes, int endMinutes) {
    // Gaps shorter than the improvement minimum are route/arrival buffers, not
    // useful standalone free-time blocks. Keeping them off the timeline also
    // prevents a 5-15 minute card
    // from interrupting consecutive manual repeat rides.
    return endMinutes - startMinutes >= 20;
  }

  ScheduleItem _freeTimeSegment({
    required ScheduleItem source,
    required String id,
    required int startMinutes,
    required int endMinutes,
  }) {
    return ScheduleItem(
      id: id,
      title: source.title,
      type: ScheduleItemType.breakTime,
      startHour: startMinutes ~/ 60,
      startMinute: startMinutes % 60,
      endHour: endMinutes ~/ 60,
      endMinute: endMinutes % 60,
      reason: source.reason,
      note: source.note,
    );
  }

  bool removeManualRepeat(String itemId) {
    final currentSchedule = schedule;
    if (currentSchedule == null || !itemId.startsWith('manual_repeat_')) {
      return false;
    }

    final targetIndex = currentSchedule.items.indexWhere(
      (item) => item.id == itemId && item.id.startsWith('manual_repeat_'),
    );
    if (targetIndex < 0) return false;

    final target = currentSchedule.items[targetIndex];
    final targetStart = target.startHour * 60 + target.startMinute;
    final targetEnd = target.endHour * 60 + target.endMinute;

    final remaining = currentSchedule.items
        .where((item) => item.id != itemId)
        .toList(growable: true)
      ..add(
        ScheduleItem(
          id: 'manual_repeat_removed_${DateTime.now().microsecondsSinceEpoch}',
          title: '休憩・自由時間',
          type: ScheduleItemType.breakTime,
          startHour: targetStart ~/ 60,
          startMinute: targetStart % 60,
          endHour: targetEnd ~/ 60,
          endMinute: targetEnd % 60,
          reason: '手動追加した再乗車を削除したため、この時間を自由時間へ戻しました。',
          note: '必要に応じて別の施設や休憩に使えます。',
        ),
      );

    remaining.sort((left, right) {
      final leftStart = left.startHour * 60 + left.startMinute;
      final rightStart = right.startHour * 60 + right.startMinute;
      if (leftStart != rightStart) return leftStart.compareTo(rightStart);
      final leftEnd = left.endHour * 60 + left.endMinute;
      final rightEnd = right.endHour * 60 + right.endMinute;
      return leftEnd.compareTo(rightEnd);
    });

    final merged = <ScheduleItem>[];
    for (final item in remaining) {
      if (merged.isNotEmpty &&
          merged.last.type == ScheduleItemType.breakTime &&
          item.type == ScheduleItemType.breakTime) {
        final previous = merged.last;
        final previousEnd = previous.endHour * 60 + previous.endMinute;
        final currentStart = item.startHour * 60 + item.startMinute;
        if (previousEnd == currentStart) {
          final mergedEnd = item.endHour * 60 + item.endMinute;
          merged[merged.length - 1] = ScheduleItem(
            id: 'merged_break_${DateTime.now().microsecondsSinceEpoch}_${merged.length}',
            title: '休憩・自由時間',
            type: ScheduleItemType.breakTime,
            startHour: previous.startHour,
            startMinute: previous.startMinute,
            endHour: mergedEnd ~/ 60,
            endMinute: mergedEnd % 60,
            reason: previous.reason ?? item.reason,
            note: previous.note ?? item.note,
          );
          continue;
        }
      }
      merged.add(item);
    }

    _appState.updateDaySchedule(
      DaySchedule(
        id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
        parkId: currentSchedule.parkId,
        items: List<ScheduleItem>.unmodifiable(merged),
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }

  List<ScheduleItem> _manualRepeatItemsForDate(DateTime targetDate) {
    final currentSchedule = schedule;
    if (currentSchedule == null || currentSchedule.parkId != selectedParkId) {
      return const <ScheduleItem>[];
    }
    final prefix = 'manual_repeat_${_dateToken(targetDate)}_';
    return currentSchedule.items
        .where((item) => item.id.startsWith(prefix))
        .toList(growable: false);
  }

  String _dateToken(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void clearSchedule() {
    errorMessage = null;
    _generatedPreferences = null;

    _appState.clearDaySchedule();
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  void _onAppStateChanged() {
    notifyListeners();
  }

  int? _parseTimeMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);

    super.dispose();
  }
}


class PerformancePlanChoice {
  const PerformancePlanChoice({
    required this.facility,
    required this.option,
  });

  final Facility facility;
  final PerformanceTimeOption option;
}


enum FreeTimeImprovementKind { facility, repeatAttraction, performance }

class FreeTimeImprovementChoice {
  const FreeTimeImprovementChoice._({
    required this.kind,
    required this.facility,
    required this.plannedStartMinutes,
    required this.plannedEndMinutes,
    required this.movementInMinutes,
    required this.movementOutMinutes,
    required this.fitSlackMinutes,
    required this.score,
    this.performanceOption,
    this.estimatedWaitMinutes,
    this.waitSource,
    this.preparationMinutes = 0,
    this.alreadySelected = false,
    this.expertScore = 0,
    this.expertReason,
    this.repeatNumber,
  });

  factory FreeTimeImprovementChoice.facility({
    required Facility facility,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int estimatedWaitMinutes,
    required String waitSource,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int fitSlackMinutes,
    required double score,
    required bool alreadySelected,
    double expertScore = 0,
    String? expertReason,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.facility,
      facility: facility,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      waitSource: waitSource,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
      alreadySelected: alreadySelected,
      expertScore: expertScore,
      expertReason: expertReason,
    );
  }

  factory FreeTimeImprovementChoice.repeatAttraction({
    required Facility facility,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int estimatedWaitMinutes,
    required String waitSource,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int fitSlackMinutes,
    required double score,
    required int repeatNumber,
    double expertScore = 0,
    String? expertReason,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.repeatAttraction,
      facility: facility,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      estimatedWaitMinutes: estimatedWaitMinutes,
      waitSource: waitSource,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
      alreadySelected: true,
      expertScore: expertScore,
      expertReason: expertReason,
      repeatNumber: repeatNumber,
    );
  }

  factory FreeTimeImprovementChoice.performance({
    required Facility facility,
    required PerformanceTimeOption option,
    required int plannedStartMinutes,
    required int plannedEndMinutes,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int preparationMinutes,
    required int fitSlackMinutes,
    required double score,
  }) {
    return FreeTimeImprovementChoice._(
      kind: FreeTimeImprovementKind.performance,
      facility: facility,
      performanceOption: option,
      plannedStartMinutes: plannedStartMinutes,
      plannedEndMinutes: plannedEndMinutes,
      movementInMinutes: movementInMinutes,
      movementOutMinutes: movementOutMinutes,
      preparationMinutes: preparationMinutes,
      fitSlackMinutes: fitSlackMinutes,
      score: score,
    );
  }

  final FreeTimeImprovementKind kind;
  final Facility facility;
  final PerformanceTimeOption? performanceOption;
  final int plannedStartMinutes;
  final int plannedEndMinutes;
  final int? estimatedWaitMinutes;
  final String? waitSource;
  final int movementInMinutes;
  final int movementOutMinutes;
  final int preparationMinutes;
  final int fitSlackMinutes;
  final double score;
  final bool alreadySelected;
  final double expertScore;
  final String? expertReason;
  final int? repeatNumber;

  String get plannedStartLabel {
    final hour = (plannedStartMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (plannedStartMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get plannedEndLabel {
    final hour = (plannedEndMinutes ~/ 60).toString().padLeft(2, '0');
    final minute = (plannedEndMinutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _FreeTimeWaitEstimate {
  const _FreeTimeWaitEstimate({required this.minutes, required this.source});

  final int minutes;
  final String source;
}
