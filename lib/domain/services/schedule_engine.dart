import '../entities/day_schedule.dart';
import '../entities/area_connection.dart';
import '../entities/event_impact.dart';
import '../entities/expert_recommendation_profile.dart';
import '../entities/facility.dart';
import '../entities/facility_location.dart';
import '../entities/greeting_wait_planning_value.dart';
import '../entities/plan_preference.dart';
import '../entities/official_performance_opportunity.dart';
import '../entities/schedule_item.dart';
import '../entities/trip_settings.dart';
import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_range.dart';
import 'entry_prediction_service.dart';
import '../enums/facility_access_method.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../enums/lottery_fallback_action.dart';
import '../enums/preferred_time.dart';
import '../enums/priority_level.dart';
import '../enums/schedule_item_type.dart';
import '../enums/wait_time_band.dart';
import 'event_impact_engine.dart';
import 'desired_exit_time_evaluator.dart';
import 'disney_expert_recommendation_service.dart';
import 'meal_planner.dart';
import 'route_optimizer.dart';
import 'time_allocator.dart';
import 'time_rounding_service.dart';

class ScheduleEngine {
  const ScheduleEngine({
    this.timeAllocator = const TimeAllocator(),
    this.mealPlanner = const MealPlanner(),
    this.routeOptimizer = const RouteOptimizer(),
    this.eventImpactEngine = const EventImpactEngine(),
    this.desiredExitTimeEvaluator = const DesiredExitTimeEvaluator(),
    this.timeRoundingService = const TimeRoundingService(),
    this.expertRecommendationService = const DisneyExpertRecommendationService(),
  });

  final TimeAllocator timeAllocator;
  final MealPlanner mealPlanner;
  final RouteOptimizer routeOptimizer;
  final EventImpactEngine eventImpactEngine;
  final DesiredExitTimeEvaluator desiredExitTimeEvaluator;
  final TimeRoundingService timeRoundingService;
  final DisneyExpertRecommendationService expertRecommendationService;

  static const int _movementDurationMinutes = 15;
  static const int _sameAreaMovementMinutes = 5;
  static const int _fallbackMealDurationMinutes = 60;
  static const int _fallbackInParkRestaurantOpenMinutes = 10 * 60;

  DaySchedule generate({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    List<EventImpact> eventImpacts = const [],
    List<TimeBandWaitProfile> waitProfiles = const [],
    Map<String, double> morningScores = const {},
    List<OfficialPerformanceOpportunity> officialPerformanceOpportunities = const [],
    List<AreaConnection> areaConnections = const [],
    List<FacilityLocation> facilityLocations = const [],
    List<ExpertRecommendationProfile> expertProfiles = const [],
    Map<String, int> unlimitedRideBufferMinutes = const <String, int>{},
    Map<String, GreetingWaitPlanningValue> greetingWaitPlanning =
        const <String, GreetingWaitPlanningValue>{},
    List<ScheduleItem> manualFixedItems = const <ScheduleItem>[],
    Set<String> optionalFacilityIds = const <String>{},
  }) {
    final items = <ScheduleItem>[];
    final visitDate = settings.visitDate ?? DateTime.now();
    final facilityLocationById = <String, FacilityLocation>{
      for (final location in facilityLocations) location.facilityId: location,
    };
    final expertProfileById = <String, ExpertRecommendationProfile>{
      for (final profile in expertProfiles)
        if (profile.appliesOn(visitDate)) profile.facilityId: profile,
    };

    final operationalFacilities = facilities.where((facility) {
      if (!facility.canAddToPlanAt(visitDate)) {
        return false;
      }

      // 営業時間未登録は「休止」ではないため候補から消さない。\n      // 休止・終了は canAddToPlanAt() でハード除外し、\n      // 日別営業時間が登録済みならその時間枠を優先する。

      return true;
    }).toList(growable: false);

    final entryPrediction = const EntryPredictionService().predict(settings);
    final entryMinutes = entryPrediction.expectedEntryMinutes;
    final planningStartMinutes =
        entryPrediction.firstFacilityAvailableMinutes;

    final exitMinutes = _toMinutes(
      settings.exitTimeHour,
      settings.exitTimeMinute,
    );

    final entryEndMinutes = _minimum(
      planningStartMinutes,
      exitMinutes,
    );

    items.add(
      _createScheduleItem(
        id: 'entry',
        title: '入園',
        type: ScheduleItemType.entry,
        startMinutes: entryMinutes,
        endMinutes: entryEndMinutes,
        reason: entryPrediction.usesHappyEntryModel
            ? '並び開始${entryPrediction.queueArrivalLabel}、'
                'ハッピーエントリー${entryPrediction.admissionStartLabel}、'
                '一般開園${entryPrediction.officialOpeningLabel}を考慮しました。'
            : '並び開始${entryPrediction.queueArrivalLabel}と'
                '公式開園予定${entryPrediction.officialOpeningLabel}から'
                '予測した入園時間です。',
      ),
    );

    final fixedRestaurantFacilityIds = _addConfirmedRestaurantReservations(
      items: items,
      facilities: operationalFacilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      targetDate: visitDate,
    );

    final fixedPerformanceFacilityIds = _addFixedPerformanceFacilities(
      items: items,
      facilities: operationalFacilities
          .where((facility) => !optionalFacilityIds.contains(facility.id))
          .toList(growable: false),
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      targetDate: visitDate,
    );

    final mustDoPerformanceFacilityIds = _addMustDoOfficialPerformanceAnchors(
      items: items,
      opportunities: officialPerformanceOpportunities,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      alreadyFixedFacilityIds: fixedPerformanceFacilityIds,
    );
    fixedPerformanceFacilityIds.addAll(mustDoPerformanceFacilityIds);

    final fixedAccessFacilityIds = _addFixedAccessFacilities(
      items: items,
      facilities: operationalFacilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      targetDate: visitDate,
      waitProfiles: waitProfiles,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );

    final operationalFacilityIds =
        operationalFacilities.map((facility) => facility.id).toSet();
    for (final manualItem in manualFixedItems) {
      final manualStart =
          manualItem.startHour * 60 + manualItem.startMinute;
      final manualEnd = manualItem.endHour * 60 + manualItem.endMinute;
      final facilityId = manualItem.facilityId;
      if (!manualItem.id.startsWith('manual_repeat_') ||
          manualItem.type != ScheduleItemType.facility ||
          facilityId == null ||
          !operationalFacilityIds.contains(facilityId) ||
          manualStart < entryEndMinutes ||
          manualEnd <= manualStart ||
          manualEnd > exitMinutes) {
        continue;
      }
      final overlapsExisting = items.any((existing) {
        final existingStart = existing.startHour * 60 + existing.startMinute;
        final existingEnd = existing.endHour * 60 + existing.endMinute;
        return manualStart < existingEnd && manualEnd > existingStart;
      });
      if (!overlapsExisting) {
        items.add(manualItem);
      }
    }

    final mealPlan = mealPlanner.plan(
      settings: settings,
      facilities: operationalFacilities,
      preferences: preferences,
      expertProfiles: expertProfiles,
      targetDate: visitDate,
    );

    for (final assignment in mealPlan.assignments) {
      if (fixedRestaurantFacilityIds.contains(assignment.facility.id)) {
        continue;
      }
      _addRestaurantMeal(
        items: items,
        assignment: assignment,
        preferences: preferences,
        entryMinutes: entryEndMinutes,
        exitMinutes: exitMinutes,
        targetDate: visitDate,
      );
    }

    _addFallbackMeals(
      items: items,
      settings: settings,
      mealPlan: mealPlan,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
    );

    final hasRequestedMealSlot =
        settings.wantsBreakfast || settings.wantsLunch || settings.wantsDinner;

    final regularFacilities = operationalFacilities
        .where((facility) {
          final isRestaurant =
              facility.category == FacilityCategory.restaurant;
          final isAssignedRestaurant =
              isRestaurant &&
              (mealPlan.assignedFacilityIds.contains(facility.id) ||
                  fixedRestaurantFacilityIds.contains(facility.id));

          final isFixedPerformance = fixedPerformanceFacilityIds.contains(
            facility.id,
          );

          final isFixedAccess = fixedAccessFacilityIds.contains(facility.id);
          final preference = _findPreference(
            facilityId: facility.id,
            preferences: preferences,
          );

          if (isAssignedRestaurant ||
              isFixedPerformance ||
              isFixedAccess ||
              (preference?.isExcluded ?? false)) {
            return false;
          }

          // When meal slots are requested, MealPlanner owns restaurant
          // selection. This prevents every selected restaurant from being
          // inserted again as an ordinary facility. If no meal slot is
          // requested, preserve the long-standing behavior that an explicitly
          // selected restaurant can still be scheduled as a normal wish item.
          if (isRestaurant && hasRequestedMealSlot) {
            return false;
          }

          // Shows/parades are time-fixed experiences. If an official/selected
          // performance time has not been resolved, never drop them into an
          // arbitrary free slot as if they were a normal attraction.
          if (_isShowOrParade(facility)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);

    final optimizedFacilities = routeOptimizer.optimize(
      facilities: regularFacilities,
      preferences: preferences,
    );

    var currentMinutes = entryEndMinutes;
    String? previousAreaId;
    final remainingFacilities = optimizedFacilities.toList(growable: true);
    final committedOpeningFacilityIds = <String>[];

    while (remainingFacilities.isNotEmpty) {
      final nextDecision = _selectNextWaitAwareFacility(
        scheduledItems: items,
        allFacilities: operationalFacilities,
        remainingFacilities: remainingFacilities,
        routeOrder: optimizedFacilities,
        preferences: preferences,
        waitProfiles: waitProfiles,
        currentMinutes: currentMinutes,
        previousAreaId: previousAreaId,
        eventImpacts: eventImpacts,
        settings: settings,
        morningScores: morningScores,
        areaConnections: areaConnections,
        facilityLocationById: facilityLocationById,
        expertProfiles: expertProfiles,
        targetDate: visitDate,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
        committedOpeningFacilityIds: committedOpeningFacilityIds,
      );
      if (nextDecision.openingSequenceFacilityIds.isNotEmpty &&
          committedOpeningFacilityIds.isEmpty) {
        committedOpeningFacilityIds.addAll(
          nextDecision.openingSequenceFacilityIds.skip(1),
        );
      }
      final facility = nextDecision.facility;
      remainingFacilities.remove(facility);
      if (committedOpeningFacilityIds.isNotEmpty &&
          committedOpeningFacilityIds.first == facility.id) {
        committedOpeningFacilityIds.removeAt(0);
      }

      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );

      final waitDecision = _evaluateWaitTolerance(
        facility: facility,
        preference: preference,
      );

      if (waitDecision.shouldSkip) {
        continue;
      }

      final preferredTime = preference?.preferredTime ?? PreferredTime.anytime;

      final allocation = timeAllocator.allocate(
        settings: settings,
        preferredTime: preferredTime,
      );

      final preferredStartMinutes = _toMinutes(
        allocation.startHour,
        allocation.startMinute,
      );

      final facilityEntryAreaId =
          facilityLocationById[facility.id]?.areaId ?? facility.areaId;
      final movementMinutes = _calculateMovementMinutes(
        previousAreaId: previousAreaId,
        currentAreaId: facilityEntryAreaId,
        atMinutes: currentMinutes,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );

      var requestedStartMinutes = _maximum(
        currentMinutes + movementMinutes,
        preferredStartMinutes,
      );

      requestedStartMinutes = _applyFacilitySpecificStartPriority(
        facility: facility,
        preference: preference,
        requestedStartMinutes: requestedStartMinutes,
        entryMinutes: entryEndMinutes,
        currentMinutes: currentMinutes,
        movementMinutes: movementMinutes,
      );

      final waitEstimate = _resolveWaitEstimate(
        facility: facility,
        preference: preference,
        waitProfiles: waitProfiles,
        scheduledStartMinutes: requestedStartMinutes,
        settings: settings,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );
      final durationMinutes = _resolvePlannedFacilityDuration(
        facility: facility,
        preference: preference,
        waitEstimate: waitEstimate,
        settings: settings,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );

      final firstAvailableStart = _findAvailableStart(
        requestedStartMinutes: requestedStartMinutes,
        durationMinutes: durationMinutes,
        items: items,
        exitMinutes: exitMinutes,
      );

      if (firstAvailableStart == null) {
        continue;
      }

      final adjustedStartMinutes = _adjustStartForOperatingHours(
        facility: facility,
        requestedStartMinutes: firstAvailableStart,
        durationMinutes: durationMinutes,
        exitMinutes: exitMinutes,
        targetDate: visitDate,
      );

      if (adjustedStartMinutes == null) {
        continue;
      }

      var finalStartMinutes = _findAvailableStart(
        requestedStartMinutes: adjustedStartMinutes,
        durationMinutes: durationMinutes,
        items: items,
        exitMinutes: exitMinutes,
      );

      if (finalStartMinutes == null) {
        continue;
      }

      finalStartMinutes = _ensureTravelAroundScheduledFacilities(
        candidateStartMinutes: finalStartMinutes,
        durationMinutes: durationMinutes,
        targetEntryAreaId: facilityEntryAreaId,
        targetExitAreaId:
            facilityLocationById[facility.id]?.effectiveExitAreaId ??
            facility.areaId,
        items: items,
        facilityLocationById: facilityLocationById,
        facilities: operationalFacilities,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
        exitMinutes: exitMinutes,
      );

      if (finalStartMinutes == null) {
        continue;
      }

      if (!_fitsOperatingHours(
        facility: facility,
        startMinutes: finalStartMinutes,
        durationMinutes: durationMinutes,
        targetDate: visitDate,
      )) {
        continue;
      }

      final finalWaitEstimate = finalStartMinutes == requestedStartMinutes
          ? waitEstimate
          : _resolveWaitEstimate(
              facility: facility,
              preference: preference,
              waitProfiles: waitProfiles,
              scheduledStartMinutes: finalStartMinutes,
              settings: settings,
              unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              greetingWaitPlanning: greetingWaitPlanning,
            );
      final finalDurationMinutes = _resolvePlannedFacilityDuration(
        facility: facility,
        preference: preference,
        waitEstimate: finalWaitEstimate,
        settings: settings,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );
      final resolvedWaitDecision = _evaluateResolvedAttractionWaitTolerance(
        facility: facility,
        preference: preference,
        waitEstimate: finalWaitEstimate,
      );
      if (resolvedWaitDecision.shouldSkip) {
        continue;
      }

      if (finalDurationMinutes != durationMinutes) {
        final refitStart = _findAvailableStart(
          requestedStartMinutes: finalStartMinutes,
          durationMinutes: finalDurationMinutes,
          items: items,
          exitMinutes: exitMinutes,
        );
        if (refitStart == null ||
            refitStart != finalStartMinutes ||
            !_fitsOperatingHours(
              facility: facility,
              startMinutes: finalStartMinutes,
              durationMinutes: finalDurationMinutes,
              targetDate: visitDate,
            )) {
          continue;
        }
      }

      final endMinutes = finalStartMinutes + finalDurationMinutes;
      final effectiveDecisionReason = _effectiveDecisionReason(
        decision: nextDecision,
        requestedStartMinutes: requestedStartMinutes,
        finalStartMinutes: finalStartMinutes,
      );

      final sameFacilityOccurrence = items
              .where((item) => item.facilityId == facility.id)
              .length +
          1;
      items.add(
        _createScheduleItem(
          id: sameFacilityOccurrence == 1
              ? 'schedule_${facility.id}'
              : 'schedule_${facility.id}_repeat_$sameFacilityOccurrence',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: finalStartMinutes,
          endMinutes: endMinutes,
          facilityId: facility.id,
          reason: _buildReason(
            facility: facility,
            preference: preference,
            previousAreaId: previousAreaId,
            currentAreaId: facilityEntryAreaId,
            durationMinutes: finalDurationMinutes,
            scheduledStartMinutes: finalStartMinutes,
            waitDecision: resolvedWaitDecision,
            waitTimingReason: effectiveDecisionReason,
            waitProfiles: waitProfiles,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
            greetingWaitPlanning: greetingWaitPlanning,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
          estimatedWaitMinutes: _usesQueueWaitPlanning(facility)
              ? finalWaitEstimate.waitMinutes
              : null,
          experienceMinutes: _usesQueueWaitPlanning(facility)
              ? _resolveFacilityDuration(facility)
              : null,
          waitEstimateSource: _usesQueueWaitPlanning(facility)
              ? finalWaitEstimate.source
              : null,
          accessMethod: preference?.accessMethod ?? FacilityAccessMethod.standby,
          usesVacationPackageUnlimited: _usesUnlimitedRideBenefit(
            facility: facility,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          ),
          standbyWaitMinutes: _usesQueueWaitPlanning(facility) &&
                  !finalWaitEstimate.isPriorityAccessBuffer
              ? finalWaitEstimate.waitMinutes
              : null,
          priorityAccessBufferMinutes: _usesQueueWaitPlanning(facility) &&
                  finalWaitEstimate.isPriorityAccessBuffer
              ? finalWaitEstimate.waitMinutes
              : null,
        ),
      );

      currentMinutes = endMinutes;
      previousAreaId =
          facilityLocationById[facility.id]?.effectiveExitAreaId ??
          facility.areaId;
    }

    // A fixed meal/show can make the forward-only pass jump over an earlier
    // gap. Revisit wishes that were not scheduled before declaring that gap
    // free time or concluding that DPA is required for full wish coverage.
    _backfillUnscheduledWishFacilities(
      items: items,
      facilities: operationalFacilities,
      regularFacilities: optimizedFacilities,
      preferences: preferences,
      waitProfiles: waitProfiles,
      settings: settings,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      facilityLocationById: facilityLocationById,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );

    // Coverage-first local repair. A greedy forward pass can leave one wish
    // unscheduled even though a different ordering would fit every wish.
    // Try a bounded one-item relocation before declaring free time or DPA
    // necessary: temporarily remove one already-scheduled regular facility,
    // then ask the existing gap fitter to place both the missing wish and the
    // displaced facility. Commit only when both are present in the trial day.
    _repairWishCoverageBySingleRelocation(
      items: items,
      facilities: operationalFacilities,
      regularFacilities: optimizedFacilities,
      preferences: preferences,
      waitProfiles: waitProfiles,
      settings: settings,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      facilityLocationById: facilityLocationById,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );

    // Unified full-day optimizer. Once coverage is complete, stop stacking
    // one-off relocation passes. Rebuild every movable wish and non-reserved
    // meal together on one 10-minute search space while keeping only genuine
    // hard anchors (fixed performances/access/reservations/manual fixed items).
    // The search is lexicographic: full coverage is mandatory, then standby
    // wait, then movement. This removes the old dependency on greedy -> single
    // -> pair repair chains and lets flexible meals participate in the same day.
    _optimizeCoveredDayByUnifiedBeamSearch(
      items: items,
      facilities: operationalFacilities,
      regularFacilities: optimizedFacilities,
      preferences: preferences,
      waitProfiles: waitProfiles,
      settings: settings,
      targetDate: visitDate,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      facilityLocationById: facilityLocationById,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );

    // The Beam Search protects hard wishes first. Re-run the existing gap
    // fitter afterwards so optional/conditional wishes can still be added when
    // their own wait condition and the remaining day genuinely allow them.
    _backfillUnscheduledWishFacilities(
      items: items,
      facilities: operationalFacilities,
      regularFacilities: optimizedFacilities,
      preferences: preferences,
      waitProfiles: waitProfiles,
      settings: settings,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      facilityLocationById: facilityLocationById,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );

    // Make long unused periods explicit instead of silently leaving multi-hour
    // holes in the generated day. These are flexible blocks, not invented
    // show times: actual shows/parades are still scheduled only when a
    // performance time has been resolved.
    final effectiveExitMinutes = _addFlexibleOpenTimeBlocks(
      items: items,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      officialPerformanceOpportunities: officialPerformanceOpportunities,
      expertProfileById: expertProfileById,
      facilities: operationalFacilities,
      preferences: preferences,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    );

    _applyIntentionalFreeTimePreference(
      items: items,
      settings: settings,
    );

    // Desired exit time is a soft constraint only for candidates that have
    // explicitly passed the generic value-vs-overtime evaluation. All other
    // generated items are still clipped at the resulting effective day end.
    items.removeWhere((item) => _itemEndMinutes(item) > effectiveExitMinutes);

    final exitWasExtended = effectiveExitMinutes > exitMinutes;
    items.add(
      _createScheduleItem(
        id: 'exit',
        title: '退園',
        type: ScheduleItemType.exit,
        startMinutes: effectiveExitMinutes,
        endMinutes: effectiveExitMinutes,
        reason: exitWasExtended
            ? '希望退園時刻を超える予定について、予定価値と超過コストを比較した結果、'
                'この時刻まで滞在するプランを採用しました。'
            : '設定された退園時間です。',
        note: exitWasExtended
            ? '希望退園時刻は${_formatMinutes(exitMinutes)}です。'
            : null,
      ),
    );

    items.sort((first, second) {
      return _itemStartMinutes(first).compareTo(_itemStartMinutes(second));
    });

    return DaySchedule(
      id:
          'schedule_'
          '${DateTime.now().millisecondsSinceEpoch}',
      parkId: settings.parkId,
      items: List<ScheduleItem>.unmodifiable(items),
      createdAt: DateTime.now(),
    );
  }

  Set<String> _addConfirmedRestaurantReservations({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required int entryMinutes,
    required int exitMinutes,
    required DateTime targetDate,
  }) {
    final added = <String>{};
    final candidates =
        facilities
            .where((facility) {
              if (!facility.isRestaurant) {
                return false;
              }
              final preference = _findPreference(
                facilityId: facility.id,
                preferences: preferences,
              );
              return preference?.fixedTimeStatus == FixedTimeStatus.confirmed &&
                  preference?.hasReservationTime == true;
            })
            .toList(growable: false)
          ..sort((a, b) {
            final pa = _findPreference(
              facilityId: a.id,
              preferences: preferences,
            )!;
            final pb = _findPreference(
              facilityId: b.id,
              preferences: preferences,
            )!;
            return (_parseTimeText(pa.reservationTime) ?? 9999).compareTo(
              _parseTimeText(pb.reservationTime) ?? 9999,
            );
          });

    for (final facility in candidates) {
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      )!;
      final start = _parseTimeText(preference.reservationTime);
      if (start == null) {
        continue;
      }
      final diningDuration = _resolveFacilityDuration(facility);
      final startWithTravel = start - facility.outboundTravelMinutes;
      final duration = facility.totalPlannedDurationMinutes;
      final end = startWithTravel + duration;
      if (startWithTravel < entryMinutes || end > exitMinutes) {
        continue;
      }
      if (!_fitsOperatingHours(
        facility: facility,
        startMinutes: start,
        durationMinutes: diningDuration,
        targetDate: targetDate,
      )) {
        continue;
      }
      if (!_isTimeRangeAvailable(
        startMinutes: startWithTravel,
        endMinutes: end,
        items: items,
      )) {
        continue;
      }

      items.add(
        _createScheduleItem(
          id: 'fixed_restaurant_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.lunch,
          startMinutes: startWithTravel,
          endMinutes: end,
          facilityId: facility.id,
          reason: facility.isHotelRestaurant
              ? 'ホテルへの往復移動を含め、事前予約済みの食事予定を固定配置しました。'
              : '事前予約済みの固定予定を最優先で配置しました。',
          note: _buildScheduleNote(facility: facility, preference: preference),
        ),
      );
      added.add(facility.id);
    }
    return added;
  }

  Set<String> _addMustDoOfficialPerformanceAnchors({
    required List<ScheduleItem> items,
    required List<OfficialPerformanceOpportunity> opportunities,
    required int entryMinutes,
    required int exitMinutes,
    required Set<String> alreadyFixedFacilityIds,
  }) {
    final added = <String>{};
    final mustDoFacilityIds = opportunities
        .where((option) => option.isSelected && option.isMustDo)
        .map((option) => option.facilityId)
        .toSet();

    for (final facilityId in mustDoFacilityIds) {
      if (alreadyFixedFacilityIds.contains(facilityId)) continue;
      final candidates = opportunities
          .where((option) =>
              option.facilityId == facilityId &&
              option.isSelected &&
              option.isMustDo &&
              !option.requiresEntryRequest &&
              option.startMinutes >= entryMinutes &&
              option.endMinutes <= exitMinutes)
          .toList(growable: false)
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      for (final option in candidates) {
        final overlapsHardAnchor = items.any((item) {
          final start = _itemStartMinutes(item);
          final end = _itemEndMinutes(item);
          return option.startMinutes < end && option.endMinutes > start;
        });
        if (overlapsHardAnchor) continue;

        items.add(_createScheduleItem(
          id: 'must_do_official_performance_${option.facilityId}',
          title: option.name,
          type: ScheduleItemType.facility,
          startMinutes: option.startMinutes,
          endMinutes: option.endMinutes,
          facilityId: option.facilityId,
          reason: '「絶対行きたい」に指定された公式公演のため、公演時刻を全日最適化の固定条件として確保しました。',
          note: option.supportsDpa
              ? 'DPA対象公演ですが、DPA購入済みを仮定せず公演時刻を確保しています。'
              : '公式公演時刻を固定条件として使用しています。',
        ));
        added.add(facilityId);
        break;
      }
    }
    return added;
  }

  Set<String> _addFixedPerformanceFacilities({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required int entryMinutes,
    required int exitMinutes,
    required DateTime targetDate,
  }) {
    final addedFacilityIds = <String>{};

    final candidates = facilities
        .where((facility) {
          return _isShowOrParade(facility);
        })
        .map((facility) {
          return _FixedPerformanceCandidate(
            facility: facility,
            preference: _findPreference(
              facilityId: facility.id,
              preferences: preferences,
            ),
          );
        })
        .where((candidate) {
          final preference = candidate.preference;
          if (preference == null || !preference.hasPreferredPerformanceTime) {
            return false;
          }
          return preference.fixedTimeStatus == FixedTimeStatus.confirmed ||
              (preference.fixedTimeStatus == FixedTimeStatus.planned &&
                  preference.accessMethod == FacilityAccessMethod.entryRequest);
        })
        .toList(growable: true);

    candidates.sort((first, second) {
      final firstTime = _parseTimeText(
        first.preference!.preferredPerformanceTime,
      );

      final secondTime = _parseTimeText(
        second.preference!.preferredPerformanceTime,
      );

      if (firstTime == null && secondTime == null) {
        return 0;
      }

      if (firstTime == null) {
        return 1;
      }

      if (secondTime == null) {
        return -1;
      }

      return firstTime.compareTo(secondTime);
    });

    for (final candidate in candidates) {
      final facility = candidate.facility;
      final preference = candidate.preference!;

      final fixedStartMinutes = _parseTimeText(
        preference.preferredPerformanceTime,
      );

      if (fixedStartMinutes == null) {
        continue;
      }

      final durationMinutes = _resolveFacilityDuration(facility);

      final fixedEndMinutes = fixedStartMinutes + durationMinutes;

      addedFacilityIds.add(facility.id);

      if (fixedStartMinutes < entryMinutes || fixedStartMinutes > exitMinutes) {
        continue;
      }

      final waitDecision = _evaluateWaitTolerance(
        facility: facility,
        preference: preference,
      );

      items.add(
        _createScheduleItem(
          id:
              'fixed_performance_'
              '${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: fixedStartMinutes,
          endMinutes: fixedEndMinutes,
          facilityId: facility.id,
          reason: _buildFixedPerformanceReason(
            facility: facility,
            preference: preference,
            durationMinutes: durationMinutes,
            waitDecision: waitDecision,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
        ),
      );
    }

    return addedFacilityIds;
  }

  Set<String> _addFixedAccessFacilities({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required int entryMinutes,
    required int exitMinutes,
    required DateTime targetDate,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final addedFacilityIds = <String>{};

    final candidates = facilities
        .map(
          (facility) => _FixedAccessCandidate(
            facility: facility,
            preference: _findPreference(
              facilityId: facility.id,
              preferences: preferences,
            ),
          ),
        )
        .where((candidate) {
          final preference = candidate.preference;

          if (preference == null ||
              !preference.hasScheduledAccessTime ||
              _isShowOrParade(candidate.facility) ||
              candidate.facility.isRestaurant) {
            return false;
          }

          final isUserPlannedStandby =
              preference.fixedTimeStatus == FixedTimeStatus.planned &&
              preference.accessMethod == FacilityAccessMethod.standby;
          if (isUserPlannedStandby) {
            return true;
          }

          if (preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
            return false;
          }

          return switch (preference.accessMethod) {
            FacilityAccessMethod.dpa => true,
            FacilityAccessMethod.priorityPass => true,
            FacilityAccessMethod.standbyPass => true,
            FacilityAccessMethod.entryRequest => true,
            FacilityAccessMethod.reservation => true,
            FacilityAccessMethod.standby => false,
            FacilityAccessMethod.freeSeating => false,
          };
        })
        .toList(growable: true);

    candidates.sort((first, second) {
      final firstTime = _parseTimeText(first.preference!.scheduledAccessTime);

      final secondTime = _parseTimeText(second.preference!.scheduledAccessTime);

      return (firstTime ?? 9999).compareTo(secondTime ?? 9999);
    });

    for (final candidate in candidates) {
      final facility = candidate.facility;
      final preference = candidate.preference!;

      final fixedStartMinutes = _parseTimeText(preference.scheduledAccessTime);

      if (fixedStartMinutes == null) {
        continue;
      }

      final isUserPlannedStandby =
          preference.fixedTimeStatus == FixedTimeStatus.planned &&
          preference.accessMethod == FacilityAccessMethod.standby;
      final usesUnlimitedRide = isUserPlannedStandby &&
          _usesUnlimitedRideBenefit(
            facility: facility,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          );
      final priorityAccessBufferMinutes = _priorityAccessBufferMinutes(
        facility: facility,
        preference: preference,
      );
      final hasPriorityAccess = priorityAccessBufferMinutes != null;
      final waitEstimate = isUserPlannedStandby
          ? _resolveWaitEstimate(
              facility: facility,
              preference: preference,
              waitProfiles: waitProfiles,
              scheduledStartMinutes: fixedStartMinutes,
              settings: settings,
              unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              greetingWaitPlanning: greetingWaitPlanning,
            )
          : hasPriorityAccess
              ? _WaitEstimate(
                  waitMinutes: priorityAccessBufferMinutes,
                  source:
                      '${preference.accessMethod.label}（優先利用バッファ$priorityAccessBufferMinutes分・Disney Planner計画値）',
                  isPriorityAccessBuffer: true,
                )
              : null;
      final durationMinutes = isUserPlannedStandby
          ? _resolvePlannedFacilityDuration(
              facility: facility,
              preference: preference,
              settings: settings,
              unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              waitEstimate: waitEstimate,
            )
          : hasPriorityAccess
              ? _resolveFacilityDuration(facility) +
                  priorityAccessBufferMinutes
              : _resolveFacilityDuration(facility);
      final fixedEndMinutes = fixedStartMinutes + durationMinutes;

      if (fixedStartMinutes < entryMinutes || fixedEndMinutes > exitMinutes) {
        continue;
      }

      if (!_fitsOperatingHours(
        facility: facility,
        startMinutes: fixedStartMinutes,
        durationMinutes: durationMinutes,
        targetDate: targetDate,
      )) {
        continue;
      }

      if (!_isTimeRangeAvailable(
        startMinutes: fixedStartMinutes,
        endMinutes: fixedEndMinutes,
        items: items,
      )) {
        continue;
      }

      items.add(
        _createScheduleItem(
          id: 'fixed_access_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: fixedStartMinutes,
          endMinutes: fixedEndMinutes,
          facilityId: facility.id,
          reason: _buildFixedAccessReason(
            facility: facility,
            preference: preference,
            durationMinutes: durationMinutes,
            usesUnlimitedRide: usesUnlimitedRide,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
          estimatedWaitMinutes:
              (isUserPlannedStandby || hasPriorityAccess) &&
                      _usesQueueWaitPlanning(facility)
                  ? waitEstimate?.waitMinutes
                  : null,
          experienceMinutes:
              (isUserPlannedStandby || hasPriorityAccess) &&
                      _usesQueueWaitPlanning(facility)
                  ? _resolveFacilityDuration(facility)
                  : null,
          waitEstimateSource:
              (isUserPlannedStandby || hasPriorityAccess) &&
                      _usesQueueWaitPlanning(facility)
                  ? waitEstimate?.source
                  : null,
          accessMethod: preference.accessMethod,
          usesVacationPackageUnlimited: usesUnlimitedRide,
          standbyWaitMinutes: waitEstimate != null &&
                  !waitEstimate.isPriorityAccessBuffer
              ? waitEstimate.waitMinutes
              : null,
          priorityAccessBufferMinutes: waitEstimate != null &&
                  waitEstimate.isPriorityAccessBuffer
              ? waitEstimate.waitMinutes
              : null,
        ),
      );

      addedFacilityIds.add(facility.id);
    }

    return addedFacilityIds;
  }

  void _backfillUnscheduledWishFacilities({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final scheduledIds = items
        .map((item) => item.facilityId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final unscheduled = regularFacilities
        .where((facility) => !scheduledIds.contains(facility.id))
        .toList(growable: false);

    for (final facility in unscheduled) {
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      if (preference?.isExcluded ?? false) continue;
      final waitDecision = _evaluateWaitTolerance(
        facility: facility,
        preference: preference,
      );
      if (waitDecision.shouldSkip) continue;

      // First estimate only finds a candidate gap. The wait is recalculated at
      // the actual gap time before insertion because afternoon/evening queues
      // can differ substantially from the morning estimate.
      var probeStart = entryMinutes;
      var inserted = false;
      for (var attempt = 0; attempt < items.length + 4 && !inserted; attempt++) {
        final probeWait = _resolveWaitEstimate(
          facility: facility,
          preference: preference,
          waitProfiles: waitProfiles,
          scheduledStartMinutes: probeStart,
          settings: settings,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          greetingWaitPlanning: greetingWaitPlanning,
        );
        final probeDuration = _resolvePlannedFacilityDuration(
          facility: facility,
          preference: preference,
          waitEstimate: probeWait,
          settings: settings,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        );
        var start = _findAvailableStart(
          requestedStartMinutes: probeStart,
          durationMinutes: probeDuration,
          items: items,
          exitMinutes: exitMinutes,
        );
        if (start == null) break;
        start = _adjustStartForOperatingHours(
          facility: facility,
          requestedStartMinutes: start,
          durationMinutes: probeDuration,
          exitMinutes: exitMinutes,
          targetDate: settings.visitDate ?? DateTime.now(),
        );
        if (start == null) break;

        final wait = _resolveWaitEstimate(
          facility: facility,
          preference: preference,
          waitProfiles: waitProfiles,
          scheduledStartMinutes: start,
          settings: settings,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          greetingWaitPlanning: greetingWaitPlanning,
        );
        final duration = _resolvePlannedFacilityDuration(
          facility: facility,
          preference: preference,
          waitEstimate: wait,
          settings: settings,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        );
        final resolvedWaitDecision = _evaluateResolvedAttractionWaitTolerance(
          facility: facility,
          preference: preference,
          waitEstimate: wait,
        );
        if (resolvedWaitDecision.shouldSkip) {
          probeStart = start + 10;
          continue;
        }
        if (duration != probeDuration) {
          final refit = _findAvailableStart(
            requestedStartMinutes: start,
            durationMinutes: duration,
            items: items,
            exitMinutes: exitMinutes,
          );
          if (refit == null) break;
          if (refit != start) {
            probeStart = refit;
            continue;
          }
        }

        final entryArea = facilityLocationById[facility.id]?.areaId ?? facility.areaId;
        final exitArea = facilityLocationById[facility.id]?.effectiveExitAreaId ?? facility.areaId;
        final travelSafeStart = _ensureTravelAroundScheduledFacilities(
          candidateStartMinutes: start,
          durationMinutes: duration,
          targetEntryAreaId: entryArea,
          targetExitAreaId: exitArea,
          items: items,
          facilityLocationById: facilityLocationById,
          facilities: facilities,
          eventImpacts: eventImpacts,
          areaConnections: areaConnections,
          exitMinutes: exitMinutes,
        );
        if (travelSafeStart == null) break;
        if (travelSafeStart != start) {
          probeStart = travelSafeStart;
          continue;
        }
        if (!_fitsOperatingHours(
          facility: facility,
          startMinutes: start,
          durationMinutes: duration,
          targetDate: settings.visitDate ?? DateTime.now(),
        )) {
          probeStart = start + 10;
          continue;
        }

        items.add(_createScheduleItem(
          id: 'backfill_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: start,
          endMinutes: start + duration,
          facilityId: facility.id,
          reason: '固定予定の前後に残った空き時間を再探索し、未採用の希望をDPA追加判定より先に組み込みました。 '
              '来園日の待ち時間・移動・施設運営時間を再計算し、この空き枠に収まることを確認しています。 '
              '所要時間を$duration分として配置しました。',
          note: _buildScheduleNote(facility: facility, preference: preference),
          estimatedWaitMinutes: _usesQueueWaitPlanning(facility) ? wait.waitMinutes : null,
          experienceMinutes: _usesQueueWaitPlanning(facility) ? _resolveFacilityDuration(facility) : null,
          waitEstimateSource: _usesQueueWaitPlanning(facility) ? wait.source : null,
          accessMethod: preference?.accessMethod ?? FacilityAccessMethod.standby,
          usesVacationPackageUnlimited: _usesUnlimitedRideBenefit(
            facility: facility,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          ),
          standbyWaitMinutes: _usesQueueWaitPlanning(facility) && !wait.isPriorityAccessBuffer
              ? wait.waitMinutes
              : null,
          priorityAccessBufferMinutes: _usesQueueWaitPlanning(facility) && wait.isPriorityAccessBuffer
              ? wait.waitMinutes
              : null,
        ));
        inserted = true;
      }
    }
  }

  void _repairWishCoverageBySingleRelocation({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final regularById = {for (final facility in regularFacilities) facility.id: facility};

    bool hasFacility(List<ScheduleItem> source, String facilityId) =>
        source.any((item) => item.facilityId == facilityId);

    // Keep the search bounded. Each successful repair strictly increases (or
    // preserves while rearranging toward) full wish coverage, and we restart
    // from the new schedule after a commit.
    for (var repairRound = 0; repairRound < regularFacilities.length; repairRound++) {
      final missing = regularFacilities
          .where((facility) => !hasFacility(items, facility.id))
          .toList(growable: false);
      if (missing.isEmpty) return;

      var committed = false;
      for (final missingFacility in missing) {
        final movableItems = items.where((item) {
          final facilityId = item.facilityId;
          return facilityId != null && regularById.containsKey(facilityId);
        }).toList(growable: false)
          ..sort((a, b) => _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));

        for (final movable in movableItems) {
          final displacedId = movable.facilityId!;
          if (displacedId == missingFacility.id) continue;
          final displaced = regularById[displacedId];
          if (displaced == null) continue;

          final trial = List<ScheduleItem>.of(items)..remove(movable);
          _backfillUnscheduledWishFacilities(
            items: trial,
            facilities: facilities,
            // Missing wish first: this explores a materially different order.
            // The displaced wish must also fit before the trial is accepted.
            regularFacilities: [missingFacility, displaced],
            preferences: preferences,
            waitProfiles: waitProfiles,
            settings: settings,
            entryMinutes: entryMinutes,
            exitMinutes: exitMinutes,
            eventImpacts: eventImpacts,
            areaConnections: areaConnections,
            facilityLocationById: facilityLocationById,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
            greetingWaitPlanning: greetingWaitPlanning,
          );

          if (!hasFacility(trial, missingFacility.id) ||
              !hasFacility(trial, displacedId)) {
            continue;
          }

          items
            ..clear()
            ..addAll(trial);
          committed = true;
          break;
        }
        if (committed) break;
      }
      if (!committed) return;
    }
  }

  // ignore: unused_element -- retained as legacy fallback/reference during unified optimizer migration.
  void _optimizeCoveredWishTimingByLocalRepack({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    if (regularFacilities.length < 2) return;
    final regularById = {for (final facility in regularFacilities) facility.id: facility};

    bool hasFullCoverage(List<ScheduleItem> candidate) {
      final ids = candidate.map((item) => item.facilityId).whereType<String>().toSet();
      return regularFacilities.every((facility) => ids.contains(facility.id));
    }

    // Do not optimize a partial plan: coverage repair owns that problem.
    if (!hasFullCoverage(items)) return;

    // Fixed anchors can also arrive on the day itself (for example a newly
    // successful Entry Request / show time). The rolling repack may move only
    // regular wishes; every non-regular timed item must survive unchanged.
    final fixedAnchorFingerprint = _coveredWishFixedAnchorFingerprint(
      items: items,
      regularFacilityIds: regularById.keys.toSet(),
    );

    var baseline = _coveredWishTimingCost(
      items: items,
      regularFacilityIds: regularById.keys.toSet(),
      facilities: facilities,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );

    // Bounded hill-climb. One- and two-item removals are enough to discover
    // useful swaps around meals/shows without factorial whole-day search.
    const maxRounds = 3;
    for (var round = 0; round < maxRounds; round++) {
      final movable = items.where((item) {
        final id = item.facilityId;
        return id != null && regularById.containsKey(id);
      }).toList(growable: false)
        ..sort((a, b) => _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));

      List<ScheduleItem>? bestTrial;
      _CoveredWishTimingCost? bestCost;

      void consider(List<ScheduleItem> trial) {
        if (!hasFullCoverage(trial)) return;
        if (_coveredWishFixedAnchorFingerprint(
              items: trial,
              regularFacilityIds: regularById.keys.toSet(),
            ) !=
            fixedAnchorFingerprint) {
          return;
        }
        final cost = _coveredWishTimingCost(
          items: trial,
          regularFacilityIds: regularById.keys.toSet(),
          facilities: facilities,
          facilityLocationById: facilityLocationById,
          eventImpacts: eventImpacts,
          areaConnections: areaConnections,
        );
        if (!_isCoveredWishTimingCostBetter(cost, baseline)) return;
        final currentBestCost = bestCost;
        if (currentBestCost == null ||
            _isCoveredWishTimingCostBetter(cost, currentBestCost)) {
          bestTrial = trial;
          bestCost = cost;
        }
      }

      void refill(List<ScheduleItem> trial, List<Facility> order) {
        _backfillUnscheduledWishFacilities(
          items: trial,
          facilities: facilities,
          regularFacilities: order,
          preferences: preferences,
          waitProfiles: waitProfiles,
          settings: settings,
          entryMinutes: entryMinutes,
          exitMinutes: exitMinutes,
          eventImpacts: eventImpacts,
          areaConnections: areaConnections,
          facilityLocationById: facilityLocationById,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          greetingWaitPlanning: greetingWaitPlanning,
        );
        consider(trial);
      }

      for (var i = 0; i < movable.length; i++) {
        final firstId = movable[i].facilityId!;
        final first = regularById[firstId]!;

        final single = List<ScheduleItem>.of(items)..remove(movable[i]);
        refill(single, [first]);

        for (var j = i + 1; j < movable.length; j++) {
          final secondId = movable[j].facilityId!;
          final second = regularById[secondId]!;
          final pairBase = List<ScheduleItem>.of(items)
            ..remove(movable[i])
            ..remove(movable[j]);

          refill(List<ScheduleItem>.of(pairBase), [first, second]);
          refill(List<ScheduleItem>.of(pairBase), [second, first]);
        }

        // Cross-anchor rolling 3-step look-ahead. Do not restrict the third
        // facility to an adjacent schedule item: a useful full-coverage repair
        // can move a wish from before a parade to the evening gap (or vice
        // versa). Non-regular timed items remain immutable through the fixed
        // anchor fingerprint above, so a same-day Entry Request/show can split
        // the future day without being moved by this search.
        //
        // Keep the expansion bounded for larger wish lists. Pairs are still
        // explored exhaustively above; triples add the extra degree of freedom
        // needed to repack across fixed anchors.
        const maxCrossAnchorTripleSetsPerRound = 60;
        var expandedTripleSets = 0;
        for (var j = i + 1;
            j < movable.length &&
                expandedTripleSets < maxCrossAnchorTripleSetsPerRound;
            j++) {
          final secondId = movable[j].facilityId!;
          final second = regularById[secondId]!;
          for (var k = j + 1;
              k < movable.length &&
                  expandedTripleSets < maxCrossAnchorTripleSetsPerRound;
              k++) {
            final thirdId = movable[k].facilityId!;
            final third = regularById[thirdId]!;
            final tripleBase = List<ScheduleItem>.of(items)
              ..remove(movable[i])
              ..remove(movable[j])
              ..remove(movable[k]);
            final permutations = <List<Facility>>[
              [first, second, third],
              [first, third, second],
              [second, first, third],
              [second, third, first],
              [third, first, second],
              [third, second, first],
            ];
            for (final order in permutations) {
              refill(List<ScheduleItem>.of(tripleBase), order);
            }
            expandedTripleSets++;
          }
        }
      }

      final selectedTrial = bestTrial;
      final selectedCost = bestCost;
      if (selectedTrial == null || selectedCost == null) return;
      items
        ..clear()
        ..addAll(selectedTrial);
      baseline = selectedCost;
    }
  }

  // ignore: unused_element -- retained as legacy fallback/reference during unified optimizer migration.
  void _optimizeCoveredWishTimingByTenMinuteSlots({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    if (regularFacilities.isEmpty) return;
    final regularById = {
      for (final facility in regularFacilities) facility.id: facility,
    };
    final regularIds = regularById.keys.toSet();

    bool hasFullCoverage(List<ScheduleItem> candidate) {
      final ids = candidate
          .map((item) => item.facilityId)
          .whereType<String>()
          .toSet();
      return regularFacilities.every((facility) => ids.contains(facility.id));
    }

    if (!hasFullCoverage(items)) return;
    final fixedAnchorFingerprint = _coveredWishFixedAnchorFingerprint(
      items: items,
      regularFacilityIds: regularIds,
    );
    var baseline = _coveredWishTimingCost(
      items: items,
      regularFacilityIds: regularIds,
      facilities: facilities,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );

    // The opening strategy answers a different question from the all-day slot
    // assignment: which attraction is most costly to defer out of the opening
    // window. Preserve that first opening choice here so a cheap late-day dip
    // cannot retroactively replace it after the dedicated opening look-ahead
    // has already selected the route. Later regular wishes remain movable.
    final openingRegularItems = items.where((item) {
      final facilityId = item.facilityId;
      return facilityId != null &&
          regularIds.contains(facilityId) &&
          _waitTimeBandForMinutes(_itemStartMinutes(item)) ==
              WaitTimeBand.afterOpening;
    }).toList(growable: false)
      ..sort((a, b) =>
          _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));
    final protectedOpeningFacilityId = openingRegularItems.isEmpty
        ? null
        : openingRegularItems.first.facilityId;

    // One committed relocation per round makes the assignment stable while
    // still allowing several attractions to exchange scarce cheap windows.
    const maxRounds = 8;
    for (var round = 0; round < maxRounds; round++) {
      final movable = items.where((item) {
        final facilityId = item.facilityId;
        return facilityId != null &&
            regularIds.contains(facilityId) &&
            facilityId != protectedOpeningFacilityId;
      }).toList(growable: false);

      // Evaluate the most time-sensitive attractions first. This does not
      // decide the winner: every feasible trial still competes on total wait.
      movable.sort((a, b) {
        final aFacility = regularById[a.facilityId!];
        final bFacility = regularById[b.facilityId!];
        if (aFacility == null || bFacility == null) return 0;
        final aSpread = _waitProfileSpreadOpportunity(
          facility: aFacility,
          waitProfiles: waitProfiles,
          scheduledStartMinutes: _itemStartMinutes(a),
        ).spreadMinutes;
        final bSpread = _waitProfileSpreadOpportunity(
          facility: bFacility,
          waitProfiles: waitProfiles,
          scheduledStartMinutes: _itemStartMinutes(b),
        ).spreadMinutes;
        return bSpread.compareTo(aSpread);
      });

      List<ScheduleItem>? bestTrial;
      _CoveredWishTimingCost? bestCost;

      for (final original in movable) {
        final facility = regularById[original.facilityId!];
        if (facility == null) continue;
        final preference = _findPreference(
          facilityId: facility.id,
          preferences: preferences,
        );
        if (preference?.isExcluded ?? false) continue;

        final base = List<ScheduleItem>.of(items)..remove(original);
        final starts = <int>{entryMinutes, _itemStartMinutes(original)};
        var slot = ((entryMinutes + 9) ~/ 10) * 10;
        while (slot < exitMinutes) {
          starts.add(slot);
          slot += 10;
        }
        final orderedStarts = starts.toList()..sort();

        for (final requestedStart in orderedStarts) {
          final wait = _resolveWaitEstimate(
            facility: facility,
            preference: preference,
            waitProfiles: waitProfiles,
            scheduledStartMinutes: requestedStart,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
            greetingWaitPlanning: greetingWaitPlanning,
          );
          final duration = _resolvePlannedFacilityDuration(
            facility: facility,
            preference: preference,
            waitEstimate: wait,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          );
          if (requestedStart + duration > exitMinutes) continue;

          // Slot assignment must score the requested slot itself. Do not let
          // the generic gap finder silently jump to a later opening.
          final available = _findAvailableStart(
            requestedStartMinutes: requestedStart,
            durationMinutes: duration,
            items: base,
            exitMinutes: exitMinutes,
          );
          if (available != requestedStart) continue;
          final operatingStart = _adjustStartForOperatingHours(
            facility: facility,
            requestedStartMinutes: requestedStart,
            durationMinutes: duration,
            exitMinutes: exitMinutes,
            targetDate: settings.visitDate ?? DateTime.now(),
          );
          if (operatingStart != requestedStart) continue;

          final entryArea =
              facilityLocationById[facility.id]?.areaId ?? facility.areaId;
          final exitArea = facilityLocationById[facility.id]
                  ?.effectiveExitAreaId ??
              facility.areaId;
          final travelSafeStart = _ensureTravelAroundScheduledFacilities(
            candidateStartMinutes: requestedStart,
            durationMinutes: duration,
            targetEntryAreaId: entryArea,
            targetExitAreaId: exitArea,
            items: base,
            facilityLocationById: facilityLocationById,
            facilities: facilities,
            eventImpacts: eventImpacts,
            areaConnections: areaConnections,
            exitMinutes: exitMinutes,
          );
          if (travelSafeStart != requestedStart) continue;
          if (!_fitsOperatingHours(
            facility: facility,
            startMinutes: requestedStart,
            durationMinutes: duration,
            targetDate: settings.visitDate ?? DateTime.now(),
          )) {
            continue;
          }

          final trial = List<ScheduleItem>.of(base)
            ..add(_createScheduleItem(
              id: 'slot_repack_${facility.id}',
              title: facility.name,
              type: ScheduleItemType.facility,
              startMinutes: requestedStart,
              endMinutes: requestedStart + duration,
              facilityId: facility.id,
              reason: '全希望と固定予定を維持したまま、来園日の待ち時間テーブルを10分刻みで比較し、'
                  '待ち時間差の大きい施設の安い時間帯を逃さないよう再配置しました。 '
                  '移動時間と施設運営時間も再確認しています。所要時間を$duration分として配置しました。',
              note: _buildScheduleNote(
                facility: facility,
                preference: preference,
              ),
              estimatedWaitMinutes:
                  _usesQueueWaitPlanning(facility) ? wait.waitMinutes : null,
              experienceMinutes: _usesQueueWaitPlanning(facility)
                  ? _resolveFacilityDuration(facility)
                  : null,
              waitEstimateSource:
                  _usesQueueWaitPlanning(facility) ? wait.source : null,
              accessMethod:
                  preference?.accessMethod ?? FacilityAccessMethod.standby,
              usesVacationPackageUnlimited: _usesUnlimitedRideBenefit(
                facility: facility,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              ),
              standbyWaitMinutes:
                  _usesQueueWaitPlanning(facility) && !wait.isPriorityAccessBuffer
                      ? wait.waitMinutes
                      : null,
              priorityAccessBufferMinutes:
                  _usesQueueWaitPlanning(facility) && wait.isPriorityAccessBuffer
                      ? wait.waitMinutes
                      : null,
            ));

          if (!hasFullCoverage(trial)) continue;
          if (_coveredWishFixedAnchorFingerprint(
                items: trial,
                regularFacilityIds: regularIds,
              ) !=
              fixedAnchorFingerprint) {
            continue;
          }
          final cost = _coveredWishTimingCost(
            items: trial,
            regularFacilityIds: regularIds,
            facilities: facilities,
            facilityLocationById: facilityLocationById,
            eventImpacts: eventImpacts,
            areaConnections: areaConnections,
          );
          if (!_isCoveredWishTimingCostBetter(cost, baseline)) continue;
          if (bestCost == null ||
              _isCoveredWishTimingCostBetter(cost, bestCost)) {
            bestTrial = trial;
            bestCost = cost;
          }
        }
      }

      if (bestTrial == null || bestCost == null) return;
      items
        ..clear()
        ..addAll(bestTrial);
      baseline = bestCost;
    }
  }

  // ignore: unused_element -- retained as legacy fallback/reference during unified optimizer migration.
  void _optimizeCoveredWishTimingByPairSlots({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    if (regularFacilities.length < 2) return;
    final regularById = {
      for (final facility in regularFacilities) facility.id: facility,
    };
    final regularIds = regularById.keys.toSet();

    bool hasFullCoverage(List<ScheduleItem> candidate) {
      final ids = candidate
          .map((item) => item.facilityId)
          .whereType<String>()
          .toSet();
      return regularFacilities.every((facility) => ids.contains(facility.id));
    }

    if (!hasFullCoverage(items)) return;
    final fixedAnchorFingerprint = _coveredWishFixedAnchorFingerprint(
      items: items,
      regularFacilityIds: regularIds,
    );
    var baseline = _coveredWishTimingCost(
      items: items,
      regularFacilityIds: regularIds,
      facilities: facilities,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );

    final openingRegularItems = items.where((item) {
      final facilityId = item.facilityId;
      return facilityId != null &&
          regularIds.contains(facilityId) &&
          _waitTimeBandForMinutes(_itemStartMinutes(item)) ==
              WaitTimeBand.afterOpening;
    }).toList(growable: false)
      ..sort((a, b) =>
          _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));
    final protectedOpeningFacilityId = openingRegularItems.isEmpty
        ? null
        : openingRegularItems.first.facilityId;

    // Four improving exchanges are enough for the small requested-facility
    // set while keeping plan generation bounded.
    const maxRounds = 4;
    const legacyPairSlotCandidateLimit = 18;
    for (var round = 0; round < maxRounds; round++) {
      final movable = items.where((item) {
        final facilityId = item.facilityId;
        return facilityId != null &&
            regularIds.contains(facilityId) &&
            facilityId != protectedOpeningFacilityId;
      }).toList(growable: false);
      if (movable.length < 2) return;

      List<ScheduleItem>? bestTrial;
      _CoveredWishTimingCost? bestCost;

      for (var i = 0; i < movable.length - 1; i++) {
        for (var j = i + 1; j < movable.length; j++) {
          final firstOriginal = movable[i];
          final secondOriginal = movable[j];
          final firstFacility = regularById[firstOriginal.facilityId!];
          final secondFacility = regularById[secondOriginal.facilityId!];
          if (firstFacility == null || secondFacility == null) continue;
          final firstPreference = _findPreference(
            facilityId: firstFacility.id,
            preferences: preferences,
          );
          final secondPreference = _findPreference(
            facilityId: secondFacility.id,
            preferences: preferences,
          );
          if ((firstPreference?.isExcluded ?? false) ||
              (secondPreference?.isExcluded ?? false)) {
            continue;
          }

          final base = List<ScheduleItem>.of(items)
            ..remove(firstOriginal)
            ..remove(secondOriginal);

          List<({int start, int duration, _WaitEstimate wait})> candidatesFor(
            Facility facility,
            PlanPreference? preference,
            ScheduleItem original,
          ) {
            final candidates = <({int start, int duration, _WaitEstimate wait})>[];
            final starts = <int>{entryMinutes, _itemStartMinutes(original)};
            var slot = ((entryMinutes + 9) ~/ 10) * 10;
            while (slot < exitMinutes) {
              starts.add(slot);
              slot += 10;
            }
            for (final requestedStart in starts) {
              final wait = _resolveWaitEstimate(
                facility: facility,
                preference: preference,
                waitProfiles: waitProfiles,
                scheduledStartMinutes: requestedStart,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
                greetingWaitPlanning: greetingWaitPlanning,
              );
              final duration = _resolvePlannedFacilityDuration(
                facility: facility,
                preference: preference,
                waitEstimate: wait,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              );
              if (requestedStart + duration > exitMinutes) continue;
              if (_findAvailableStart(
                    requestedStartMinutes: requestedStart,
                    durationMinutes: duration,
                    items: base,
                    exitMinutes: exitMinutes,
                  ) !=
                  requestedStart) {
                continue;
              }
              if (_adjustStartForOperatingHours(
                    facility: facility,
                    requestedStartMinutes: requestedStart,
                    durationMinutes: duration,
                    exitMinutes: exitMinutes,
                    targetDate: settings.visitDate ?? DateTime.now(),
                  ) !=
                  requestedStart) {
                continue;
              }
              candidates.add((start: requestedStart, duration: duration, wait: wait));
            }
            candidates.sort((a, b) {
              final byWait = a.wait.waitMinutes.compareTo(b.wait.waitMinutes);
              if (byWait != 0) return byWait;
              final aDistance = (a.start - _itemStartMinutes(original)).abs();
              final bDistance = (b.start - _itemStartMinutes(original)).abs();
              return aDistance.compareTo(bDistance);
            });
            return candidates.take(legacyPairSlotCandidateLimit).toList(growable: false);
          }

          final firstCandidates =
              candidatesFor(firstFacility, firstPreference, firstOriginal);
          final secondCandidates =
              candidatesFor(secondFacility, secondPreference, secondOriginal);
          if (firstCandidates.isEmpty || secondCandidates.isEmpty) continue;

          ScheduleItem buildItem(
            Facility facility,
            PlanPreference? preference,
            ({int start, int duration, _WaitEstimate wait}) candidate,
          ) {
            return _createScheduleItem(
              id: 'pair_slot_repack_${facility.id}',
              title: facility.name,
              type: ScheduleItemType.facility,
              startMinutes: candidate.start,
              endMinutes: candidate.start + candidate.duration,
              facilityId: facility.id,
              reason: '全希望と固定予定を維持したまま、2施設の時間枠を同時に外して10分刻みで交換探索し、'
                  '単独移動では使えなかった安い待ち時間帯へ再配置しました。 '
                  '移動時間と施設運営時間も再確認しています。所要時間を${candidate.duration}分として配置しました。',
              note: _buildScheduleNote(
                facility: facility,
                preference: preference,
              ),
              estimatedWaitMinutes: _usesQueueWaitPlanning(facility)
                  ? candidate.wait.waitMinutes
                  : null,
              experienceMinutes: _usesQueueWaitPlanning(facility)
                  ? _resolveFacilityDuration(facility)
                  : null,
              waitEstimateSource: _usesQueueWaitPlanning(facility)
                  ? candidate.wait.source
                  : null,
              accessMethod:
                  preference?.accessMethod ?? FacilityAccessMethod.standby,
              usesVacationPackageUnlimited: _usesUnlimitedRideBenefit(
                facility: facility,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
              ),
              standbyWaitMinutes: _usesQueueWaitPlanning(facility) &&
                      !candidate.wait.isPriorityAccessBuffer
                  ? candidate.wait.waitMinutes
                  : null,
              priorityAccessBufferMinutes: _usesQueueWaitPlanning(facility) &&
                      candidate.wait.isPriorityAccessBuffer
                  ? candidate.wait.waitMinutes
                  : null,
            );
          }

          for (final firstCandidate in firstCandidates) {
            for (final secondCandidate in secondCandidates) {
              final firstEnd = firstCandidate.start + firstCandidate.duration;
              final secondEnd = secondCandidate.start + secondCandidate.duration;
              if (firstCandidate.start < secondEnd &&
                  secondCandidate.start < firstEnd) {
                continue;
              }
              final firstItem =
                  buildItem(firstFacility, firstPreference, firstCandidate);
              final secondItem =
                  buildItem(secondFacility, secondPreference, secondCandidate);
              final trial = List<ScheduleItem>.of(base)
                ..add(firstItem)
                ..add(secondItem);

              bool travelSafe(
                ScheduleItem target,
                Facility facility,
                int duration,
              ) {
                final withoutTarget = List<ScheduleItem>.of(trial)..remove(target);
                final entryArea =
                    facilityLocationById[facility.id]?.areaId ?? facility.areaId;
                final exitArea = facilityLocationById[facility.id]
                        ?.effectiveExitAreaId ??
                    facility.areaId;
                return _ensureTravelAroundScheduledFacilities(
                      candidateStartMinutes: _itemStartMinutes(target),
                      durationMinutes: duration,
                      targetEntryAreaId: entryArea,
                      targetExitAreaId: exitArea,
                      items: withoutTarget,
                      facilityLocationById: facilityLocationById,
                      facilities: facilities,
                      eventImpacts: eventImpacts,
                      areaConnections: areaConnections,
                      exitMinutes: exitMinutes,
                    ) ==
                    _itemStartMinutes(target);
              }

              if (!travelSafe(firstItem, firstFacility, firstCandidate.duration) ||
                  !travelSafe(secondItem, secondFacility, secondCandidate.duration)) {
                continue;
              }
              if (!hasFullCoverage(trial)) continue;
              if (_coveredWishFixedAnchorFingerprint(
                    items: trial,
                    regularFacilityIds: regularIds,
                  ) !=
                  fixedAnchorFingerprint) {
                continue;
              }
              final cost = _coveredWishTimingCost(
                items: trial,
                regularFacilityIds: regularIds,
                facilities: facilities,
                facilityLocationById: facilityLocationById,
                eventImpacts: eventImpacts,
                areaConnections: areaConnections,
              );
              if (!_isCoveredWishTimingCostBetter(cost, baseline)) continue;
              if (bestCost == null ||
                  _isCoveredWishTimingCostBetter(cost, bestCost)) {
                bestTrial = trial;
                bestCost = cost;
              }
            }
          }
        }
      }

      if (bestTrial == null || bestCost == null) return;
      final committedTrial = bestTrial;
      final committedCost = bestCost;
      items
        ..clear()
        ..addAll(committedTrial);
      baseline = committedCost;
    }
  }

  void _optimizeCoveredDayByUnifiedBeamSearch({
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required List<Facility> regularFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required TripSettings settings,
    required DateTime targetDate,
    required int entryMinutes,
    required int exitMinutes,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    // The unified search is responsible for hard wishes only. Optional
    // ("できれば") wishes are opportunistic and may legitimately be omitted
    // when their wait condition is not satisfied. Requiring them as mandatory
    // full-coverage targets can make the whole Beam Search fail and leave a
    // normal/must-do wish unscheduled even with large free-time blocks.
    bool isOptionalWish(Facility facility) {
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      final priority = preference?.priority;
      return priority == PriorityLevel.low || priority == PriorityLevel.lowest;
    }

    final mandatoryRegularFacilities = regularFacilities
        .where((facility) => !isOptionalWish(facility))
        .toList(growable: false);
    final regularIds = mandatoryRegularFacilities
        .map((facility) => facility.id)
        .toSet();
    final allRegularIds = regularFacilities.map((facility) => facility.id).toSet();

    Map<String, int> occurrenceCounts(Iterable<Facility> source) {
      final counts = <String, int>{};
      for (final facility in source) {
        counts[facility.id] = (counts[facility.id] ?? 0) + 1;
      }
      return counts;
    }

    final requiredOccurrenceCounts = occurrenceCounts(mandatoryRegularFacilities);

    // Coverage is occurrence-based. A repeated hard wish must remain repeated;
    // a set-of-IDs check would incorrectly treat 1/2 as full coverage.
    bool hasFullRegularWishCoverage(List<ScheduleItem> candidate) {
      final scheduledCounts = <String, int>{};
      for (final item in candidate) {
        final facilityId = item.facilityId;
        if (facilityId == null || !requiredOccurrenceCounts.containsKey(facilityId)) {
          continue;
        }
        scheduledCounts[facilityId] = (scheduledCounts[facilityId] ?? 0) + 1;
      }
      for (final entry in requiredOccurrenceCounts.entries) {
        if ((scheduledCounts[entry.key] ?? 0) < entry.value) return false;
      }
      return true;
    }

    bool isFlexibleMeal(ScheduleItem item) {
      if (item.id.startsWith('fixed_restaurant_')) return false;
      return item.type == ScheduleItemType.breakfast ||
          item.type == ScheduleItemType.lunch ||
          item.type == ScheduleItemType.dinner;
    }

    // The opening strategy has its own objective (defer-loss, day difficulty,
    // transport ambiguity, congestion traps). A full-day standby-wait search
    // must not overwrite that decision merely because another first facility
    // has a cheaper whole-day wait sum.
    //
    // Preserve the first regular facility that the opening strategy already
    // committed in the after-opening band. The rest of the regular wishes and
    // non-reserved meals remain globally movable.
    final openingCommittedItem = items
        .where((item) {
          final facilityId = item.facilityId;
          if (facilityId == null || !regularIds.contains(facilityId)) {
            return false;
          }
          return _waitTimeBandForMinutes(_itemStartMinutes(item)) ==
              WaitTimeBand.afterOpening;
        })
        .fold<ScheduleItem?>(null, (earliest, item) {
          if (earliest == null) return item;
          return _itemStartMinutes(item) < _itemStartMinutes(earliest)
              ? item
              : earliest;
        });

    final movable = items.where((item) {
      if (identical(item, openingCommittedItem)) return false;
      final facilityId = item.facilityId;
      return (facilityId != null && regularIds.contains(facilityId)) ||
          isFlexibleMeal(item);
    }).toList(growable: true);

    // If the greedy/backfill phase missed a regular wish, synthesize a search
    // template for it instead of returning before Beam Search. The Beam Search
    // recalculates wait, duration, operating hours and movement for every slot,
    // so these placeholder times are never committed as-is.
    final representedOccurrenceCounts = <String, int>{};
    void countRepresented(String? facilityId) {
      if (facilityId == null || !regularIds.contains(facilityId)) return;
      representedOccurrenceCounts[facilityId] =
          (representedOccurrenceCounts[facilityId] ?? 0) + 1;
    }
    countRepresented(openingCommittedItem?.facilityId);
    for (final item in movable) {
      countRepresented(item.facilityId);
    }
    final synthesizedOccurrenceCounts = <String, int>{};
    for (final facility in mandatoryRegularFacilities) {
      final represented = representedOccurrenceCounts[facility.id] ?? 0;
      final synthesized = synthesizedOccurrenceCounts[facility.id] ?? 0;
      final required = requiredOccurrenceCounts[facility.id] ?? 1;
      if (represented + synthesized >= required) continue;
      final occurrence = represented + synthesized + 1;
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      movable.add(
        ScheduleItem(
          id: occurrence == 1
              ? 'schedule_${facility.id}'
              : 'schedule_${facility.id}_repeat_$occurrence',
          title: facility.name,
          type: ScheduleItemType.facility,
          startHour: entryMinutes ~/ 60,
          startMinute: entryMinutes % 60,
          endHour: entryMinutes ~/ 60,
          endMinute: entryMinutes % 60,
          facilityId: facility.id,
          reason: '',
          accessMethod:
              preference?.accessMethod ?? FacilityAccessMethod.standby,
        ),
      );
      synthesizedOccurrenceCounts[facility.id] = synthesized + 1;
    }
    if (movable.isEmpty) return;

    // Genuine anchors plus the opening-strategy commitment. Flexible meals are
    // intentionally excluded here unless they are confirmed reservations.
    // Optional wishes are also excluded from anchors: they must never block a
    // hard wish. They are re-added opportunistically after the hard-wish Beam
    // Search completes.
    final hardAnchors = items.where((item) {
      if (movable.contains(item)) return false;
      final facilityId = item.facilityId;
      if (facilityId != null &&
          allRegularIds.contains(facilityId) &&
          !regularIds.contains(facilityId)) {
        return false;
      }
      return true;
    }).toList();
    final facilityById = {for (final facility in facilities) facility.id: facility};
    final templateByKey = <String, ScheduleItem>{for (final item in movable) item.id: item};
    final allKeys = templateByKey.keys.toSet();

    // Lower-bound wait for each remaining regular wish. Comparing only the
    // wait already accumulated by a partial state unfairly favors states that
    // simply postpone an expensive attraction. Add an optimistic remaining
    // wait estimate so Beam pruning compares states on the same full-day basis.
    final minimumWaitByKey = <String, int>{};
    if (settings.scheduleOptimizationMode == ScheduleOptimizationMode.minimumWait) {
      for (final key in allKeys) {
        final template = templateByKey[key]!;
        final facilityId = template.facilityId;
        if (facilityId == null || !regularIds.contains(facilityId)) {
          minimumWaitByKey[key] = 0;
          continue;
        }
        final facility = facilityById[facilityId];
        if (facility == null) {
          minimumWaitByKey[key] = 0;
          continue;
        }
        final preference = _findPreference(
          facilityId: facility.id,
          preferences: preferences,
        );
        int? bestWait;
        for (var slot = ((entryMinutes + 9) ~/ 10) * 10;
            slot < exitMinutes;
            slot += 10) {
          final wait = _resolveWaitEstimate(
            facility: facility,
            preference: preference,
            waitProfiles: waitProfiles,
            scheduledStartMinutes: slot,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
            greetingWaitPlanning: greetingWaitPlanning,
          );
          final duration = _resolvePlannedFacilityDuration(
            facility: facility,
            preference: preference,
            settings: settings,
            unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
            waitEstimate: wait,
          );
          if (duration <= 0 || slot + duration > exitMinutes) continue;
          if (!_fitsOperatingHours(
            facility: facility,
            startMinutes: slot,
            durationMinutes: duration,
            targetDate: targetDate,
          )) {
            continue;
          }
          final standby = wait.isPriorityAccessBuffer ? 0 : wait.waitMinutes;
          if (bestWait == null || standby < bestWait) bestWait = standby;
        }
        minimumWaitByKey[key] = bestWait ?? 0;
      }
    }

    int optimisticWaitFor(_UnifiedDaySearchState state) {
      if (settings.scheduleOptimizationMode != ScheduleOptimizationMode.minimumWait) {
        return state.standbyWaitMinutes;
      }
      var total = state.standbyWaitMinutes;
      for (final key in state.remaining) {
        total += minimumWaitByKey[key] ?? 0;
      }
      return total;
    }

    // Keep a reasonably wide frontier. Unlike the previous pair search, no
    // per-facility "best 18 slots" pre-filter is used; every legal 10-minute
    // start can reach the frontier before dominance pruning.
    // Fixed performances split the day into narrow feasible windows. With two
    // optional shows plus the user's existing fixed anchors, a width of 320 can
    // prune the only full-coverage route before Baymax is placed. Keep a wider
    // frontier here; subset-level optional search already limits how many full
    // day generations are attempted.
    const beamWidth = 720;
    var frontier = <_UnifiedDaySearchState>[
      _UnifiedDaySearchState(items: List<ScheduleItem>.from(hardAnchors), remaining: allKeys),
    ];

    for (var depth = 0; depth < movable.length; depth++) {
      final expanded = <_UnifiedDaySearchState>[];
      for (final state in frontier) {
        for (final key in state.remaining) {
          final template = templateByKey[key]!;
          final facilityId = template.facilityId;
          final facility = facilityId == null ? null : facilityById[facilityId];
          final isRegular = facilityId != null && regularIds.contains(facilityId);
          if (isRegular && facility == null) continue;

          var earliest = entryMinutes;
          var latest = exitMinutes;
          if (template.type == ScheduleItemType.breakfast) {
            latest = _minimum(latest, _toMinutes(10, 0));
          } else if (template.type == ScheduleItemType.lunch) {
            earliest = _maximum(earliest, _toMinutes(11, 0));
            latest = _minimum(latest, _toMinutes(14, 0));
          } else if (template.type == ScheduleItemType.dinner) {
            earliest = _maximum(earliest, _toMinutes(17, 0));
            latest = _minimum(latest, _toMinutes(20, 0));
          }

          final starts = <int>{_itemStartMinutes(template)};
          for (var slot = ((earliest + 9) ~/ 10) * 10; slot < latest; slot += 10) {
            starts.add(slot);
          }

          for (final requestedStart in starts) {
            if (requestedStart < earliest || requestedStart >= latest) continue;
            _WaitEstimate? wait;
            var duration = _itemEndMinutes(template) - _itemStartMinutes(template);
            if (isRegular) {
              final preference = _findPreference(
                facilityId: facility!.id,
                preferences: preferences,
              );
              wait = _resolveWaitEstimate(
                facility: facility,
                preference: preference,
                waitProfiles: waitProfiles,
                scheduledStartMinutes: requestedStart,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
                greetingWaitPlanning: greetingWaitPlanning,
              );
              duration = _resolvePlannedFacilityDuration(
                facility: facility,
                preference: preference,
                settings: settings,
                unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
                waitEstimate: wait,
              );
            }
            if (duration <= 0 || requestedStart + duration > exitMinutes) continue;

            if (!_isTimeRangeAvailable(
              startMinutes: requestedStart,
              endMinutes: requestedStart + duration,
              items: state.items,
            )) {
              continue;
            }
            if (facility != null && !_fitsOperatingHours(
              facility: facility,
              startMinutes: requestedStart,
              durationMinutes: duration,
              targetDate: targetDate,
            )) {
              continue;
            }
            if (facility != null) {
              final travelChecked = _ensureTravelAroundScheduledFacilities(
                candidateStartMinutes: requestedStart,
                durationMinutes: duration,
                targetEntryAreaId:
                    facilityLocationById[facility.id]?.areaId ?? facility.areaId,
                targetExitAreaId:
                    facilityLocationById[facility.id]?.effectiveExitAreaId ?? facility.areaId,
                items: state.items,
                facilityLocationById: facilityLocationById,
                facilities: facilities,
                eventImpacts: eventImpacts,
                areaConnections: areaConnections,
                exitMinutes: exitMinutes,
              );
              // A shifted result belongs to another explicit slot and is not
              // silently accepted. This keeps the search space observable.
              if (travelChecked != requestedStart) continue;
            }

            final placed = ScheduleItem(
              id: template.id,
              title: template.title,
              type: template.type,
              startHour: requestedStart ~/ 60,
              startMinute: requestedStart % 60,
              endHour: (requestedStart + duration) ~/ 60,
              endMinute: (requestedStart + duration) % 60,
              facilityId: template.facilityId,
              reason: isRegular
                  ? '全希望と固定予定を維持した全日制約探索で、来園日の待ち時間テーブルを10分刻みで比較して配置しました。'
                  : template.reason,
              note: template.note,
              estimatedWaitMinutes: isRegular && wait != null && !wait.isPriorityAccessBuffer
                  ? wait.waitMinutes
                  : template.estimatedWaitMinutes,
              experienceMinutes: isRegular && facility != null
                  ? _resolveFacilityDuration(facility)
                  : template.experienceMinutes,
              waitEstimateSource: isRegular && wait != null ? wait.source : template.waitEstimateSource,
              accessMethod: template.accessMethod,
              usesVacationPackageUnlimited: template.usesVacationPackageUnlimited,
              standbyWaitMinutes: isRegular && wait != null && !wait.isPriorityAccessBuffer
                  ? wait.waitMinutes
                  : template.standbyWaitMinutes,
              priorityAccessBufferMinutes: isRegular && wait != null && wait.isPriorityAccessBuffer
                  ? wait.waitMinutes
                  : template.priorityAccessBufferMinutes,
            );
            final nextItems = List<ScheduleItem>.from(state.items)..add(placed);
            final nextRemaining = Set<String>.from(state.remaining)..remove(key);
            final cost = _coveredWishTimingCost(
              items: nextItems,
              regularFacilityIds: regularIds,
              facilities: facilities,
              facilityLocationById: facilityLocationById,
              eventImpacts: eventImpacts,
              areaConnections: areaConnections,
            );
            expanded.add(_UnifiedDaySearchState(
              items: nextItems,
              remaining: nextRemaining,
              standbyWaitMinutes: cost.standbyWaitMinutes,
              movementMinutes: cost.movementMinutes,
              fragmentedFreeMinutes: cost.fragmentedFreeMinutes,
              compactFragmentationMinutes: cost.compactFragmentationMinutes,
            ));
          }
        }
      }
      if (expanded.isEmpty) return;

      expanded.sort((a, b) => _compareUnifiedOptimizationCost(
            _CoveredWishTimingCost(
              standbyWaitMinutes: optimisticWaitFor(a),
              movementMinutes: a.movementMinutes,
              fragmentedFreeMinutes: a.fragmentedFreeMinutes,
              compactFragmentationMinutes: a.compactFragmentationMinutes,
            ),
            _CoveredWishTimingCost(
              standbyWaitMinutes: optimisticWaitFor(b),
              movementMinutes: b.movementMinutes,
              fragmentedFreeMinutes: b.fragmentedFreeMinutes,
              compactFragmentationMinutes: b.compactFragmentationMinutes,
            ),
            settings.scheduleOptimizationMode,
          ));

      // Dominance pruning by the actual placed schedule fingerprint keeps
      // equivalent states from consuming the frontier without deleting slots
      // merely because their individual wait rank is low.
      final seen = <String>{};
      final nextFrontier = <_UnifiedDaySearchState>[];
      final remainingGroupCounts = <String, int>{};
      // Do not over-collapse states that have the same remaining facilities.
      // Their already-placed times can sit on different sides of fixed show
      // anchors and therefore have very different completion feasibility.
      const minimumWaitPerRemainingGroupLimit = 72;
      for (final state in expanded) {
        final ordered = state.items.toList()
          ..sort((a, b) => _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));
        final fingerprint = ordered
            .map((item) => '${item.id}@${_itemStartMinutes(item)}')
            .join('|');
        if (!seen.add(fingerprint)) continue;

        if (settings.scheduleOptimizationMode == ScheduleOptimizationMode.minimumWait) {
          final remainingKey = state.remaining.toList()..sort();
          final groupFingerprint = remainingKey.join('|');
          final groupCount = remainingGroupCounts[groupFingerprint] ?? 0;
          if (groupCount >= minimumWaitPerRemainingGroupLimit) continue;
          remainingGroupCounts[groupFingerprint] = groupCount + 1;
        }

        nextFrontier.add(state);
        if (nextFrontier.length >= beamWidth) break;
      }
      frontier = nextFrontier;
    }

    final completed = frontier.where((state) => state.remaining.isEmpty).toList();
    if (completed.isEmpty) return;
    completed.sort((a, b) => _compareUnifiedOptimizationCost(
          _CoveredWishTimingCost(
            standbyWaitMinutes: a.standbyWaitMinutes,
            movementMinutes: a.movementMinutes,
            fragmentedFreeMinutes: a.fragmentedFreeMinutes,
            compactFragmentationMinutes: a.compactFragmentationMinutes,
          ),
          _CoveredWishTimingCost(
            standbyWaitMinutes: b.standbyWaitMinutes,
            movementMinutes: b.movementMinutes,
            fragmentedFreeMinutes: b.fragmentedFreeMinutes,
            compactFragmentationMinutes: b.compactFragmentationMinutes,
          ),
          settings.scheduleOptimizationMode,
        ));
    final best = completed.first;
    // Product invariant: original hard wishes are absolute. Never commit a
    // Beam Search result that drops even one requested regular facility.
    if (!hasFullRegularWishCoverage(best.items)) return;

    final baseline = _coveredWishTimingCost(
      items: items,
      regularFacilityIds: regularIds,
      facilities: facilities,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );
    final candidate = _coveredWishTimingCost(
      items: best.items,
      regularFacilityIds: regularIds,
      facilities: facilities,
      facilityLocationById: facilityLocationById,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );
    // Coverage is lexicographically more important than wait/movement cost.
    // When the provisional baseline has already dropped a requested facility
    // (for example Baymax after adding a fixed Forest Theatre performance),
    // comparing raw wait cost makes the incomplete baseline look artificially
    // cheaper and rejects the complete Beam Search result. Accept any complete
    // candidate over an incomplete baseline; compare optimization cost only
    // when both schedules already have full regular-wish coverage.
    final baselineHasFullCoverage = hasFullRegularWishCoverage(items);
    if (baselineHasFullCoverage &&
        !_isUnifiedOptimizationCostBetter(
          candidate,
          baseline,
          settings.scheduleOptimizationMode,
        )) {
      return;
    }

    items
      ..clear()
      ..addAll(best.items);
  }


  String _coveredWishFixedAnchorFingerprint({
    required List<ScheduleItem> items,
    required Set<String> regularFacilityIds,
  }) {
    final anchors = items.where((item) {
      final facilityId = item.facilityId;
      return facilityId == null || !regularFacilityIds.contains(facilityId);
    }).map((item) =>
        '${item.id}@${_itemStartMinutes(item)}-${_itemEndMinutes(item)}').toList()
      ..sort();
    return anchors.join('|');
  }

  _CoveredWishTimingCost _coveredWishTimingCost({
    required List<ScheduleItem> items,
    required Set<String> regularFacilityIds,
    required List<Facility> facilities,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
  }) {
    final facilityById = {for (final facility in facilities) facility.id: facility};
    final ordered = items.where((item) => item.facilityId != null).toList(growable: false)
      ..sort((a, b) => _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));

    var standbyWaitMinutes = 0;
    for (final item in ordered) {
      if (regularFacilityIds.contains(item.facilityId)) {
        standbyWaitMinutes += item.standbyWaitMinutes ?? item.estimatedWaitMinutes ?? 0;
      }
    }

    var movementMinutes = 0;
    for (var index = 1; index < ordered.length; index++) {
      final previousId = ordered[index - 1].facilityId;
      final currentId = ordered[index].facilityId;
      if (previousId == null || currentId == null) continue;
      final previous = facilityById[previousId];
      final current = facilityById[currentId];
      if (previous == null || current == null) continue;
      final fromArea = facilityLocationById[previousId]?.effectiveExitAreaId ?? previous.areaId;
      final toArea = facilityLocationById[currentId]?.areaId ?? current.areaId;
      movementMinutes += _calculateMovementMinutes(
        previousAreaId: fromArea,
        currentAreaId: toArea,
        atMinutes: _itemEndMinutes(ordered[index - 1]),
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );
    }

    var fragmentedFreeMinutes = 0;
    final usableFreeGaps = <int>[];
    final timeline = items
        .where((item) =>
            item.type != ScheduleItemType.entry &&
            item.type != ScheduleItemType.exit)
        .toList(growable: false)
      ..sort((a, b) => _itemStartMinutes(a).compareTo(_itemStartMinutes(b)));
    for (var index = 1; index < timeline.length; index++) {
      final previous = timeline[index - 1];
      final current = timeline[index];
      final rawGap = _itemStartMinutes(current) - _itemEndMinutes(previous);
      if (rawGap <= 0) continue;

      var requiredTravel = 0;
      final previousId = previous.facilityId;
      final currentId = current.facilityId;
      if (previousId != null && currentId != null) {
        final previousFacility = facilityById[previousId];
        final currentFacility = facilityById[currentId];
        if (previousFacility != null && currentFacility != null) {
          requiredTravel = _calculateMovementMinutes(
            previousAreaId:
                facilityLocationById[previousId]?.effectiveExitAreaId ??
                    previousFacility.areaId,
            currentAreaId:
                facilityLocationById[currentId]?.areaId ??
                    currentFacility.areaId,
            atMinutes: _itemEndMinutes(previous),
            eventImpacts: eventImpacts,
            areaConnections: areaConnections,
          );
        }
      }
      final usableGap = rawGap - requiredTravel;
      if (usableGap > 0) {
        usableFreeGaps.add(usableGap);
      }
      // A large continuous gap is useful for an extra attraction, shopping or
      // rest. Penalize only awkward fragments instead of "free time" itself.
      if (usableGap >= 10 && usableGap < 45) {
        fragmentedFreeMinutes += usableGap;
      }
    }

    // compactSchedule should consolidate usable slack, not merely avoid small
    // gaps. Minimize all usable internal slack outside the single largest gap.
    // This distinguishes one long free block from several medium blocks while
    // leaving the other optimization modes' scoring unchanged.
    final totalUsableFreeMinutes = usableFreeGaps.fold<int>(0, (sum, gap) => sum + gap);
    final largestUsableFreeMinutes = usableFreeGaps.isEmpty
        ? 0
        : usableFreeGaps.reduce((a, b) => a >= b ? a : b);
    final compactFragmentationMinutes =
        totalUsableFreeMinutes - largestUsableFreeMinutes;

    return _CoveredWishTimingCost(
      standbyWaitMinutes: standbyWaitMinutes,
      movementMinutes: movementMinutes,
      fragmentedFreeMinutes: fragmentedFreeMinutes,
      compactFragmentationMinutes: compactFragmentationMinutes,
    );
  }

  double _unifiedOptimizationScore({
    required int waitMinutes,
    required int movementMinutes,
    required int fragmentedFreeMinutes,
    required int compactFragmentationMinutes,
    required ScheduleOptimizationMode mode,
  }) {
    switch (mode) {
      case ScheduleOptimizationMode.minimumWait:
        return waitMinutes +
            movementMinutes * 0.45 +
            fragmentedFreeMinutes * 0.35;
      case ScheduleOptimizationMode.minimumWalking:
        return waitMinutes * 0.55 +
            movementMinutes * 2.0 +
            fragmentedFreeMinutes * 0.70;
      case ScheduleOptimizationMode.compactSchedule:
        return waitMinutes * 0.65 +
            movementMinutes * 0.80 +
            fragmentedFreeMinutes * 0.50 +
            compactFragmentationMinutes * 2.0;
      case ScheduleOptimizationMode.balanced:
        return waitMinutes +
            movementMinutes * 1.40 +
            fragmentedFreeMinutes * 1.20;
    }
  }

  int _compareUnifiedOptimizationCost(
    _CoveredWishTimingCost a,
    _CoveredWishTimingCost b,
    ScheduleOptimizationMode mode,
  ) {
    // minimumWait is deliberately lexicographic. Full desired-facility
    // coverage and fixed anchors have already been enforced before this
    // optimizer runs, so walking/free-time must never buy a longer standby
    // total in this mode.
    if (mode == ScheduleOptimizationMode.minimumWait) {
      final waitCompare =
          a.standbyWaitMinutes.compareTo(b.standbyWaitMinutes);
      if (waitCompare != 0) return waitCompare;
      final movementCompare = a.movementMinutes.compareTo(b.movementMinutes);
      if (movementCompare != 0) return movementCompare;
      return a.fragmentedFreeMinutes.compareTo(b.fragmentedFreeMinutes);
    }

    final aScore = _unifiedOptimizationScore(
      waitMinutes: a.standbyWaitMinutes,
      movementMinutes: a.movementMinutes,
      fragmentedFreeMinutes: a.fragmentedFreeMinutes,
      compactFragmentationMinutes: a.compactFragmentationMinutes,
      mode: mode,
    );
    final bScore = _unifiedOptimizationScore(
      waitMinutes: b.standbyWaitMinutes,
      movementMinutes: b.movementMinutes,
      fragmentedFreeMinutes: b.fragmentedFreeMinutes,
      compactFragmentationMinutes: b.compactFragmentationMinutes,
      mode: mode,
    );
    final scoreCompare = aScore.compareTo(bScore);
    if (scoreCompare != 0) return scoreCompare;
    final waitCompare = a.standbyWaitMinutes.compareTo(b.standbyWaitMinutes);
    if (waitCompare != 0) return waitCompare;
    final movementCompare = a.movementMinutes.compareTo(b.movementMinutes);
    if (movementCompare != 0) return movementCompare;
    return a.fragmentedFreeMinutes.compareTo(b.fragmentedFreeMinutes);
  }

  bool _isUnifiedOptimizationCostBetter(
    _CoveredWishTimingCost candidate,
    _CoveredWishTimingCost baseline,
    ScheduleOptimizationMode mode,
  ) {
    return _compareUnifiedOptimizationCost(candidate, baseline, mode) < 0;
  }

  bool _isCoveredWishTimingCostBetter(
    _CoveredWishTimingCost candidate,
    _CoveredWishTimingCost baseline,
  ) {
    if (candidate.standbyWaitMinutes != baseline.standbyWaitMinutes) {
      return candidate.standbyWaitMinutes < baseline.standbyWaitMinutes;
    }
    return candidate.movementMinutes < baseline.movementMinutes;
  }

  int _addFlexibleOpenTimeBlocks({
    required List<ScheduleItem> items,
    required int entryMinutes,
    required int exitMinutes,
    required List<OfficialPerformanceOpportunity> officialPerformanceOpportunities,
    required Map<String, ExpertRecommendationProfile> expertProfileById,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
  }) {
    const minimumGapMinutes = 60;
    const publicPerformanceArrivalBufferMinutes = 20;

    final occupied = items
        .where((item) => item.type != ScheduleItemType.entry && item.type != ScheduleItemType.exit)
        .toList(growable: false)
      ..sort((first, second) =>
          _itemStartMinutes(first).compareTo(_itemStartMinutes(second)));

    final gaps = <({int start, int end})>[];
    var cursor = entryMinutes;
    for (final item in occupied) {
      final start = _itemStartMinutes(item);
      final end = _itemEndMinutes(item);
      if (start - cursor >= minimumGapMinutes) {
        gaps.add((start: cursor, end: start));
      }
      if (end > cursor) cursor = end;
    }
    // The final window may be shorter than the normal flexible-block
    // threshold. Keep it as a scheduling window so a fixed-time candidate
    // close to the desired exit can still be evaluated instead of being
    // discarded before the soft-constraint comparison runs.
    if (exitMinutes > cursor) {
      gaps.add((start: cursor, end: exitMinutes));
    }

    var performanceIndex = 0;
    var flexIndex = 0;
    var effectiveExitMinutes = exitMinutes;
    for (final gap in gaps) {
      final isFinalExitGap = gap.end == exitMinutes;
      final candidates = officialPerformanceOpportunities
          .where((option) =>
              option.startMinutes >= gap.start &&
              option.startMinutes < gap.end &&
              (option.endMinutes <= gap.end || isFinalExitGap) &&
              _performanceCandidateFitsSurroundingTravel(
                option: option,
                items: items,
                facilities: facilities,
                facilityLocationById: facilityLocationById,
                eventImpacts: eventImpacts,
                areaConnections: areaConnections,
              ))
          .toList(growable: false)
        ..sort((a, b) {
          if (a.isSelected != b.isSelected) return a.isSelected ? -1 : 1;
          final aExpert = expertProfileById[a.facilityId]?.experienceScore ?? 50;
          final bExpert = expertProfileById[b.facilityId]?.experienceScore ?? 50;
          final expertCompare = bExpert.compareTo(aExpert);
          if (expertCompare != 0) return expertCompare;
          return a.startMinutes.compareTo(b.startMinutes);
        });

      // A user-selected performance is a real planning request. Unselected
      // public performances are considered automatically only in the evening,
      // after attraction planning has finished. This prevents a morning show
      // from consuming the valuable rope-drop window. Entry-Request shows are
      // never treated as won before the result is known.
      final schedulable = candidates.where((option) {
        final expert = expertProfileById[option.facilityId];
        final isHighExpertValue = expert != null &&
            (expert.experienceScore >= 85 || expert.scarcityScore >= 70);
        return option.isSelected ||
            (!option.requiresEntryRequest &&
                (option.startMinutes >= 17 * 60 ||
                    (isHighExpertValue && option.startMinutes >= 11 * 60)));
      }).toList(growable: false);

      var gapCursor = gap.start;
      for (final option in schedulable) {
        final arrivalBuffer = option.isSelected
            ? 0
            : publicPerformanceArrivalBufferMinutes;
        final plannedStart = _maximum(gapCursor, option.startMinutes - arrivalBuffer);
        if (plannedStart > option.startMinutes ||
            (!isFinalExitGap && option.endMinutes > gap.end)) {
          continue;
        }

        DesiredExitTimeEvaluation? exitEvaluation;
        if (option.endMinutes > exitMinutes) {
          final performanceDuration =
              _maximum(0, option.endMinutes - option.startMinutes).toDouble();
          final preExitOpportunityMinutes = _maximum(
            0,
            exitMinutes - option.startMinutes,
          ).clamp(0, performanceDuration.toInt()).toDouble();
          // Expert Recommendation can decide whether a performance is worth
          // considering, but it must not manufacture extra value solely to
          // justify exceeding the user's desired exit time. Overtime remains
          // governed by the generic soft-constraint model: actual performance
          // duration, value available before exit, and explicit user intent.
          exitEvaluation = desiredExitTimeEvaluator.evaluate(
            desiredExitMinutes: exitMinutes,
            candidateEndMinutes: option.endMinutes,
            experienceValueMinutes: performanceDuration,
            opportunityValueMinutes: preExitOpportunityMinutes,
            userPreferenceValueMinutes:
                option.isSelected ? performanceDuration : 0.0,
          );
          if (!exitEvaluation.shouldAccept) {
            continue;
          }
        }

        if (plannedStart - gapCursor >= minimumGapMinutes) {
          _addOpenTimeBlock(
            items: items,
            index: flexIndex++,
            startMinutes: gapCursor,
            endMinutes: plannedStart,
            officialPerformanceOpportunities: candidates,
          );
        }

        final exitReason = exitEvaluation == null
            ? ''
            : ' 希望退園${_formatMinutes(exitMinutes)}を'
                '${exitEvaluation.overtimeMinutes}分超えますが、'
                '予定価値${exitEvaluation.totalValueMinutes.toStringAsFixed(0)}分相当と'
                '超過コスト${exitEvaluation.totalCostMinutes.toStringAsFixed(0)}分相当を比較し、'
                '組み込む価値が上回ると判断しました。';
        final expertProfile = expertProfileById[option.facilityId];
        final expertReason = expertProfile == null
            ? ''
            : ' Disney通おすすめでは体験価値${expertProfile.experienceScore}/100、'
                '独自性${expertProfile.uniquenessScore}/100、'
                '希少性${expertProfile.scarcityScore}/100として評価しています。';

        items.add(
          _createScheduleItem(
            id: 'official_performance_${performanceIndex++}_${option.facilityId}',
            title: option.name,
            type: ScheduleItemType.facility,
            startMinutes: plannedStart,
            endMinutes: option.endMinutes,
            facilityId: option.facilityId,
            reason: option.isSelected
                ? '希望している公式公演の実施時刻に合わせて固定予定として配置しました。$exitReason'
                : '長い空き時間と公式公演時刻を照合し、エントリー受付の当選を仮定せず通常鑑賞できる公演を予定へ組み込みました。'
                    '公演開始${option.startLabel}に間に合うよう、鑑賞場所への移動・準備時間を含めています。$expertReason$exitReason',
            note: option.requiresEntryRequest
                ? 'エントリー受付対象です。未当選の公演を自動配置することはありません。'
                : option.supportsDpa
                    ? 'DPA対象公演ですが、この予定はDPA購入済みを仮定していません。必要に応じて当日の取得結果で再最適化してください。'
                    : 'assets/master/performance_schedules.jsonの日付別公演時刻を使用しています。',
          ),
        );
        gapCursor = option.endMinutes;
        if (option.endMinutes > effectiveExitMinutes) {
          effectiveExitMinutes = option.endMinutes;
        }
      }

      if (gap.end - gapCursor >= minimumGapMinutes) {
        _addOpenTimeBlock(
          items: items,
          index: flexIndex++,
          startMinutes: gapCursor,
          endMinutes: gap.end,
          officialPerformanceOpportunities: candidates,
        );
      }
    }

    return effectiveExitMinutes;
  }

  bool _performanceCandidateFitsSurroundingTravel({
    required OfficialPerformanceOpportunity option,
    required List<ScheduleItem> items,
    required List<Facility> facilities,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
  }) {
    const preparationMinutes = 15;

    Facility? performanceFacility;
    for (final facility in facilities) {
      if (facility.id == option.facilityId) {
        performanceFacility = facility;
        break;
      }
    }
    final performanceAreaId =
        facilityLocationById[option.facilityId]?.areaId ??
        performanceFacility?.areaId;

    ScheduleItem? previous;
    ScheduleItem? next;
    for (final item in items) {
      final facilityId = item.facilityId;
      if (facilityId == null || facilityId.isEmpty) continue;
      final itemEnd = _itemEndMinutes(item);
      final itemStart = _itemStartMinutes(item);
      if (itemEnd <= option.startMinutes &&
          (previous == null || itemEnd > _itemEndMinutes(previous))) {
        previous = item;
      }
      if (itemStart >= option.endMinutes &&
          (next == null || itemStart < _itemStartMinutes(next))) {
        next = item;
      }
    }

    if (previous != null) {
      final previousAreaId = _scheduleItemExitAreaId(
        item: previous,
        facilities: facilities,
        facilityLocationById: facilityLocationById,
      );
      final movement = performanceAreaId == null || previousAreaId == null
          ? _movementDurationMinutes
          : _calculateMovementMinutes(
              previousAreaId: previousAreaId,
              currentAreaId: performanceAreaId,
              atMinutes: _itemEndMinutes(previous),
              eventImpacts: eventImpacts,
              areaConnections: areaConnections,
            );
      final latestArrival = option.startMinutes - preparationMinutes;
      if (_itemEndMinutes(previous) + movement > latestArrival) {
        return false;
      }
    }

    if (next != null) {
      final nextAreaId = _scheduleItemEntryAreaId(
        item: next,
        facilities: facilities,
        facilityLocationById: facilityLocationById,
      );
      final movement = performanceAreaId == null || nextAreaId == null
          ? _movementDurationMinutes
          : _calculateMovementMinutes(
              previousAreaId: performanceAreaId,
              currentAreaId: nextAreaId,
              atMinutes: option.endMinutes,
              eventImpacts: eventImpacts,
              areaConnections: areaConnections,
            );
      if (option.endMinutes + movement > _itemStartMinutes(next)) {
        return false;
      }
    }

    return true;
  }

  String? _scheduleItemEntryAreaId({
    required ScheduleItem item,
    required List<Facility> facilities,
    required Map<String, FacilityLocation> facilityLocationById,
  }) {
    final facilityId = item.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    final location = facilityLocationById[facilityId];
    if (location != null) return location.areaId;
    for (final facility in facilities) {
      if (facility.id == facilityId) return facility.areaId;
    }
    return null;
  }

  String? _scheduleItemExitAreaId({
    required ScheduleItem item,
    required List<Facility> facilities,
    required Map<String, FacilityLocation> facilityLocationById,
  }) {
    final facilityId = item.facilityId;
    if (facilityId == null || facilityId.isEmpty) return null;
    final location = facilityLocationById[facilityId];
    if (location != null) return location.effectiveExitAreaId;
    for (final facility in facilities) {
      if (facility.id == facilityId) return facility.areaId;
    }
    return null;
  }

  void _addOpenTimeBlock({
    required List<ScheduleItem> items,
    required int index,
    required int startMinutes,
    required int endMinutes,
    required List<OfficialPerformanceOpportunity> officialPerformanceOpportunities,
  }) {
    const eveningStartMinutes = 17 * 60;
    final isEvening = endMinutes > eveningStartMinutes;
    final unresolvedOptions = officialPerformanceOpportunities
        .where((option) =>
            option.requiresEntryRequest &&
            !option.isSelected &&
            option.startMinutes >= startMinutes &&
            option.startMinutes < endMinutes)
        .toList(growable: false);
    final optionText = unresolvedOptions.map((option) => option.displayLabel).join('、');

    items.add(
      _createScheduleItem(
        id: 'flex_open_time_$index',
        title: isEvening ? '夜の自由時間' : '休憩・自由時間',
        type: ScheduleItemType.breakTime,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        reason: unresolvedOptions.isNotEmpty
            ? 'この時間帯にはエントリー受付対象の公式公演があります。候補：$optionText。'
                '未当選のため時間は予約していません。当選した場合は公演を固定し、当日の状況に合わせてプランを再生成します。'
            : isEvening
                ? '公式公演を配置した後にも残った夜時間です。買い物、休憩、写真撮影、当日の追加施設などに使えます。'
                : '希望施設と固定予定を配置した後に60分以上残った時間です。追加施設を捏造せず自由枠として明示します。',
        note: unresolvedOptions.isNotEmpty
            ? '通常の自由時間として利用できます。落選時はショーDPAなど、設定されたフォールバック方針を別枠で検討します。'
            : '必要に応じて当日の状況を見て追加施設へ変更できます。',
      ),
    );
  }

  void _applyIntentionalFreeTimePreference({
    required List<ScheduleItem> items,
    required TripSettings settings,
  }) {
    final preference = settings.freeTimePreference;
    if (!preference.enabled || preference.targetMinutes <= 0) return;

    final candidates = items.where((item) {
      if (item.type != ScheduleItemType.breakTime ||
          !item.id.startsWith('flex_open_time_')) {
        return false;
      }
      final start = _itemStartMinutes(item);
      final end = _itemEndMinutes(item);
      final duration = end - start;
      if (duration < preference.minimumBlockMinutes) return false;
      switch (preference.preferredTime) {
        case PreferredTime.morning:
          return start < 12 * 60;
        case PreferredTime.afternoon:
          return end > 12 * 60 && start < 17 * 60;
        case PreferredTime.evening:
          return end > 17 * 60;
        case PreferredTime.anytime:
          return true;
      }
    }).toList(growable: false);
    if (candidates.isEmpty) return;

    candidates.sort((a, b) {
      final aDuration = _itemEndMinutes(a) - _itemStartMinutes(a);
      final bDuration = _itemEndMinutes(b) - _itemStartMinutes(b);
      final aShortfall = preference.targetMinutes > aDuration
          ? preference.targetMinutes - aDuration
          : 0;
      final bShortfall = preference.targetMinutes > bDuration
          ? preference.targetMinutes - bDuration
          : 0;
      final shortfallCompare = aShortfall.compareTo(bShortfall);
      if (shortfallCompare != 0) return shortfallCompare;
      return bDuration.compareTo(aDuration);
    });

    final selected = candidates.first;
    final index = items.indexOf(selected);
    if (index < 0) return;
    final duration = _itemEndMinutes(selected) - _itemStartMinutes(selected);
    final achieved = duration >= preference.targetMinutes;
    items[index] = ScheduleItem(
      id: 'intentional_free_time_${selected.id}',
      title: '予定を入れない自由時間',
      type: selected.type,
      startHour: selected.startHour,
      startMinute: selected.startMinute,
      endHour: selected.endHour,
      endMinute: selected.endMinute,
      facilityId: selected.facilityId,
      reason: achieved
          ? '予定を詰めすぎない設定により、${preference.targetMinutes}分を目安に意図的な自由時間として確保しました。'
          : '予定を詰めすぎない設定を考慮し、確保できた最長の自由時間を意図的な余白として残しました。',
      note: '当日は遅れの吸収、休憩、買い物、写真撮影、空いている施設への寄り道などに使えます。',
    );
  }

  void _addFallbackMeals({
    required List<ScheduleItem> items,
    required TripSettings settings,
    required MealPlan mealPlan,
    required int entryMinutes,
    required int exitMinutes,
  }) {
    if (settings.wantsBreakfast &&
        _hasBreakfastTime(settings) &&
        mealPlan.assignmentFor(MealSlot.breakfast) == null) {
      _addFallbackMeal(
        items: items,
        id: 'breakfast',
        title: '朝食',
        type: ScheduleItemType.breakfast,
        requestedStartMinutes: entryMinutes,
        entryMinutes: entryMinutes,
        exitMinutes: exitMinutes,
        latestStartMinutes: _toMinutes(10, 0),
        reason:
            '朝食ありの設定ですが、'
            '選択済みの朝食レストランがないため'
            '通常の朝食予定を追加しました。',
      );
    }

    if (settings.wantsLunch && mealPlan.assignmentFor(MealSlot.lunch) == null) {
      _addFallbackMeal(
        items: items,
        id: 'lunch',
        title: '昼食',
        type: ScheduleItemType.lunch,
        requestedStartMinutes: _selectFlexibleMealStart(
              slot: MealSlot.lunch,
              preferredStartMinutes: _toMinutes(12, 0),
              durationMinutes: _fallbackMealDurationMinutes,
              items: items,
              entryMinutes: entryMinutes,
              exitMinutes: exitMinutes,
            ) ??
            _toMinutes(12, 0),
        entryMinutes: entryMinutes,
        exitMinutes: exitMinutes,
        reason:
            '昼食ありの設定ですが、'
            '選択済みの昼食レストランがないため'
            '通常の昼食予定を追加しました。',
      );
    }

    if (settings.wantsDinner &&
        mealPlan.assignmentFor(MealSlot.dinner) == null) {
      _addFallbackMeal(
        items: items,
        id: 'dinner',
        title: '夕食',
        type: ScheduleItemType.dinner,
        requestedStartMinutes: _selectFlexibleMealStart(
              slot: MealSlot.dinner,
              preferredStartMinutes: _toMinutes(18, 0),
              durationMinutes: _fallbackMealDurationMinutes,
              items: items,
              entryMinutes: entryMinutes,
              exitMinutes: exitMinutes,
            ) ??
            _toMinutes(18, 0),
        entryMinutes: entryMinutes,
        exitMinutes: exitMinutes,
        reason:
            '夕食ありの設定ですが、'
            '選択済みの夕食レストランがないため'
            '通常の夕食予定を追加しました。',
      );
    }
  }

  int? _selectFlexibleMealStart({
    required MealSlot slot,
    required int preferredStartMinutes,
    required int durationMinutes,
    required List<ScheduleItem> items,
    required int entryMinutes,
    required int exitMinutes,
    Facility? facility,
    DateTime? targetDate,
  }) {
    // Non-reserved meals are soft constraints. Search 10-minute starts inside
    // a broad meal window instead of pinning lunch/dinner to 12:00/18:00.
    // The peak penalty is deliberately a planning heuristic, not observed wait
    // data; real restaurant observations can replace it later.
    final (windowStart, windowEnd, peakCenter) = switch (slot) {
      MealSlot.breakfast => (entryMinutes, _toMinutes(10, 0), _toMinutes(8, 30)),
      MealSlot.lunch => (_toMinutes(11, 0), _toMinutes(14, 0), _toMinutes(12, 0)),
      MealSlot.dinner => (_toMinutes(17, 0), _toMinutes(20, 0), _toMinutes(18, 0)),
    };
    final start = _maximum(windowStart, entryMinutes);
    final latest = _minimum(windowEnd, exitMinutes - durationMinutes);
    if (latest < start) return null;

    int? bestStart;
    double? bestScore;
    for (var candidate = ((start + 9) ~/ 10) * 10;
        candidate <= latest;
        candidate += 10) {
      final end = candidate + durationMinutes;
      if (!_isTimeRangeAvailable(
        startMinutes: candidate,
        endMinutes: end,
        items: items,
      )) {
        continue;
      }
      if (facility != null && targetDate != null &&
          !_fitsOperatingHours(
            facility: facility,
            startMinutes: candidate,
            durationMinutes: durationMinutes,
            targetDate: targetDate,
          )) {
        continue;
      }

      final peakDistance = (candidate - peakCenter).abs();
      final peakPenalty = peakDistance < 40
          ? 120.0
          : peakDistance < 60
              ? 45.0
              : 0.0;
      final preferencePenalty =
          (candidate - preferredStartMinutes).abs() * 0.15;
      final edgePenalty = slot == MealSlot.breakfast ? 0.0 :
          (candidate == start || candidate == latest ? 2.0 : 0.0);
      final score = peakPenalty + preferencePenalty + edgePenalty;
      if (bestScore == null || score < bestScore ||
          (score == bestScore && candidate < bestStart!)) {
        bestScore = score;
        bestStart = candidate;
      }
    }
    return bestStart;
  }

  void _addRestaurantMeal({
    required List<ScheduleItem> items,
    required MealAssignment assignment,
    required List<PlanPreference> preferences,
    required int entryMinutes,
    required int exitMinutes,
    required DateTime targetDate,
  }) {
    final facility = assignment.facility;

    final preference = _findPreference(
      facilityId: facility.id,
      preferences: preferences,
    );

    final waitDecision = _evaluateWaitTolerance(
      facility: facility,
      preference: preference,
    );

    if (waitDecision.shouldSkip) {
      return;
    }

    final reservationMinutes = _parseTimeText(
      preference?.reservationTime ?? '',
    );

    final hasReservation =
        preference?.fixedTimeStatus == FixedTimeStatus.confirmed &&
        reservationMinutes != null;

    final durationMinutes = _resolveFacilityDuration(facility);
    final flexibleMealStartMinutes = hasReservation
        ? null
        : _selectFlexibleMealStart(
            slot: assignment.slot,
            preferredStartMinutes: assignment.startMinutes,
            durationMinutes: durationMinutes,
            items: items,
            entryMinutes: entryMinutes,
            exitMinutes: exitMinutes,
            facility: facility,
            targetDate: targetDate,
          );
    final requestedStartMinutes = hasReservation
        ? reservationMinutes
        : flexibleMealStartMinutes ??
            _maximum(assignment.startMinutes, entryMinutes);

    if (hasReservation) {
      final reservationEndMinutes = requestedStartMinutes + durationMinutes;

      if (requestedStartMinutes < entryMinutes ||
          reservationEndMinutes > exitMinutes) {
        return;
      }

      if (!_fitsOperatingHours(
        facility: facility,
        startMinutes: requestedStartMinutes,
        durationMinutes: durationMinutes,
        targetDate: targetDate,
      )) {
        return;
      }

      if (!_isTimeRangeAvailable(
        startMinutes: requestedStartMinutes,
        endMinutes: reservationEndMinutes,
        items: items,
      )) {
        return;
      }

      items.add(
        _createScheduleItem(
          id:
              '${assignment.slot.name}_'
              '${facility.id}',
          title: facility.name,
          type: _scheduleTypeForMealSlot(assignment.slot),
          startMinutes: requestedStartMinutes,
          endMinutes: reservationEndMinutes,
          facilityId: facility.id,
          reason: _buildMealReason(
            assignment: assignment,
            preference: preference,
            durationMinutes: durationMinutes,
            waitDecision: waitDecision,
            usedReservationTime: true,
            flexibleMealTimeOptimized: false,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
        ),
      );

      return;
    }

    final adjustedStartMinutes = _adjustStartForOperatingHours(
      facility: facility,
      requestedStartMinutes: requestedStartMinutes,
      durationMinutes: durationMinutes,
      exitMinutes: exitMinutes,
      targetDate: targetDate,
    );

    if (adjustedStartMinutes == null) {
      return;
    }

    final startMinutes = _findAvailableStart(
      requestedStartMinutes: adjustedStartMinutes,
      durationMinutes: durationMinutes,
      items: items,
      exitMinutes: exitMinutes,
    );

    if (startMinutes == null) {
      return;
    }

    if (assignment.slot == MealSlot.breakfast &&
        startMinutes >= _toMinutes(10, 0)) {
      return;
    }

    if (!_fitsOperatingHours(
      facility: facility,
      startMinutes: startMinutes,
      durationMinutes: durationMinutes,
      targetDate: targetDate,
    )) {
      return;
    }

    items.add(
      _createScheduleItem(
        id:
            '${assignment.slot.name}_'
            '${facility.id}',
        title: facility.name,
        type: _scheduleTypeForMealSlot(assignment.slot),
        startMinutes: startMinutes,
        endMinutes: startMinutes + durationMinutes,
        facilityId: facility.id,
        reason: _buildMealReason(
          assignment: assignment,
          preference: preference,
          durationMinutes: durationMinutes,
          waitDecision: waitDecision,
          usedReservationTime: false,
          flexibleMealTimeOptimized:
              requestedStartMinutes != assignment.startMinutes,
        ),
        note: _buildScheduleNote(facility: facility, preference: preference),
      ),
    );
  }

  void _addFallbackMeal({
    required List<ScheduleItem> items,
    required String id,
    required String title,
    required ScheduleItemType type,
    required int requestedStartMinutes,
    required int entryMinutes,
    required int exitMinutes,
    required String reason,
    int? latestStartMinutes,
  }) {
    final safeRequestedStart = _maximum(requestedStartMinutes, entryMinutes);

    final startMinutes = _findAvailableStart(
      requestedStartMinutes: safeRequestedStart,
      durationMinutes: _fallbackMealDurationMinutes,
      items: items,
      exitMinutes: exitMinutes,
    );

    if (startMinutes == null) {
      return;
    }

    if (latestStartMinutes != null && startMinutes >= latestStartMinutes) {
      return;
    }

    items.add(
      _createScheduleItem(
        id: id,
        title: title,
        type: type,
        startMinutes: startMinutes,
        endMinutes: startMinutes + _fallbackMealDurationMinutes,
        reason: reason,
      ),
    );
  }

  _WaitToleranceDecision _evaluateWaitTolerance({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    if (preference == null) {
      return const _WaitToleranceDecision(shouldSkip: false);
    }

    // Attraction standby waits are evaluated relatively from collected
    // historical/current wait data by the wait-aware scheduler. A fixed
    // user-entered minute ceiling (15/30/60) is not a meaningful admission
    // rule for modern park waits, so it must never remove an attraction.
    if (facility.category == FacilityCategory.attraction) {
      return const _WaitToleranceDecision(shouldSkip: false);
    }

    final waitTime = facility.waitTime;

    if (waitTime == null) {
      return const _WaitToleranceDecision(shouldSkip: false);
    }

    final waitMinutes = waitTime.minutes;
    final tolerance = preference.waitTolerance;
    final maxMinutes = tolerance.maxMinutes;

    if (maxMinutes == null) {
      return _WaitToleranceDecision(
        shouldSkip: false,
        waitMinutes: waitMinutes,
        reason: '待ち時間は気にしない設定です。',
      );
    }

    final effectiveWaitMinutes = _effectiveWaitMinutes(
      facility: facility,
      preference: preference,
      originalWaitMinutes: waitMinutes,
    );

    if (effectiveWaitMinutes <= maxMinutes) {
      return _WaitToleranceDecision(
        shouldSkip: false,
        waitMinutes: waitMinutes,
        effectiveWaitMinutes: effectiveWaitMinutes,
        maxMinutes: maxMinutes,
        reason: '予想待ち時間は許容範囲内です。',
      );
    }

    final exceededMinutes = effectiveWaitMinutes - maxMinutes;

    final keepsDespiteExceeding = _isHighPriority(preference);

    if (keepsDespiteExceeding) {
      return _WaitToleranceDecision(
        shouldSkip: false,
        waitMinutes: waitMinutes,
        effectiveWaitMinutes: effectiveWaitMinutes,
        maxMinutes: maxMinutes,
        exceededMinutes: exceededMinutes,
        exceededButKept: true,
        reason:
            '許容時間を$exceededMinutes分超えますが、'
            '優先度が高いため候補に残しました。',
      );
    }

    return _WaitToleranceDecision(
      shouldSkip: true,
      waitMinutes: waitMinutes,
      effectiveWaitMinutes: effectiveWaitMinutes,
      maxMinutes: maxMinutes,
      exceededMinutes: exceededMinutes,
      reason:
          '予想待ち時間が許容時間を'
          '$exceededMinutes分超えるため、'
          '今回の予定から除外しました。',
    );
  }

  _WaitToleranceDecision _evaluateResolvedAttractionWaitTolerance({
    required Facility facility,
    required PlanPreference? preference,
    required _WaitEstimate waitEstimate,
  }) {
    if (facility.category != FacilityCategory.attraction || preference == null) {
      return _evaluateWaitTolerance(
        facility: facility,
        preference: preference,
      );
    }

    final maxMinutes = preference.waitTolerance.maxMinutes;
    if (maxMinutes == null) {
      return _WaitToleranceDecision(
        shouldSkip: false,
        waitMinutes: waitEstimate.waitMinutes,
        effectiveWaitMinutes: waitEstimate.waitMinutes,
        reason: '待ち時間は気にしない設定です。',
      );
    }

    final effectiveWaitMinutes = waitEstimate.isPriorityAccessBuffer
        ? 0
        : waitEstimate.waitMinutes;
    if (effectiveWaitMinutes <= maxMinutes) {
      return _WaitToleranceDecision(
        shouldSkip: false,
        waitMinutes: waitEstimate.waitMinutes,
        effectiveWaitMinutes: effectiveWaitMinutes,
        maxMinutes: maxMinutes,
        reason: '予想待ち時間は希望の目安以内です。',
      );
    }

    final exceededMinutes = effectiveWaitMinutes - maxMinutes;
    final keepWish = _isHighPriority(preference);
    return _WaitToleranceDecision(
      shouldSkip: !keepWish,
      waitMinutes: waitEstimate.waitMinutes,
      effectiveWaitMinutes: effectiveWaitMinutes,
      maxMinutes: maxMinutes,
      exceededMinutes: exceededMinutes,
      exceededButKept: keepWish,
      reason: keepWish
          ? '待ち時間の目安を$exceededMinutes分超えますが、通常または絶対行きたい希望のため候補に残しました。'
          : '「できれば」の待ち時間条件を$exceededMinutes分超えるため、この時間帯では見送りました。',
    );
  }

  int _effectiveWaitMinutes({
    required Facility facility,
    required PlanPreference preference,
    required int originalWaitMinutes,
  }) {
    final accessMethod = preference.accessMethod;

    if (accessMethod == FacilityAccessMethod.dpa && facility.supportsDpa) {
      return 0;
    }

    if (accessMethod == FacilityAccessMethod.priorityPass &&
        facility.supportsPriorityPass) {
      return 0;
    }

    if (accessMethod == FacilityAccessMethod.standbyPass &&
        facility.supportsStandbyPass) {
      return 0;
    }

    if (accessMethod == FacilityAccessMethod.entryRequest &&
        facility.requiresEntryRequest) {
      return 0;
    }

    if (accessMethod == FacilityAccessMethod.reservation) {
      return 0;
    }

    if (preference.useDpa && facility.supportsDpa) {
      return 0;
    }

    if (preference.usePriorityPass && facility.supportsPriorityPass) {
      return 0;
    }

    if (preference.useStandbyPass && facility.supportsStandbyPass) {
      return 0;
    }

    return originalWaitMinutes;
  }

  bool _isHighPriority(PlanPreference preference) {
    return preference.priority.name == 'high' ||
        preference.priority.name == 'highest';
  }

  int _calculateMovementMinutes({
    required String? previousAreaId,
    required String currentAreaId,
    required int atMinutes,
    required List<EventImpact> eventImpacts,
    List<AreaConnection> areaConnections = const [],
  }) {
    if (previousAreaId == null) {
      return 0;
    }

    final baseMinutes = previousAreaId == currentAreaId
        ? _sameAreaMovementMinutes
        : (_movementMinutesFromConnections(
              fromAreaId: previousAreaId,
              toAreaId: currentAreaId,
              connections: areaConnections,
            ) ??
            _movementDurationMinutes);

    if (eventImpactEngine.isRouteBlocked(
      fromAreaId: previousAreaId,
      toAreaId: currentAreaId,
      atMinutes: atMinutes,
      impacts: eventImpacts,
    )) {
      return baseMinutes + 30;
    }

    return baseMinutes +
        eventImpactEngine.movementPenaltyMinutes(
          fromAreaId: previousAreaId,
          toAreaId: currentAreaId,
          atMinutes: atMinutes,
          impacts: eventImpacts,
        );
  }


  int? _movementMinutesFromConnections({
    required String fromAreaId,
    required String toAreaId,
    required List<AreaConnection> connections,
  }) {
    if (fromAreaId == toAreaId) return _sameAreaMovementMinutes;
    if (connections.isEmpty) return null;

    final distances = <String, int>{fromAreaId: 0};
    final visited = <String>{};
    while (true) {
      String? current;
      var best = 1 << 30;
      for (final entry in distances.entries) {
        if (!visited.contains(entry.key) && entry.value < best) {
          current = entry.key;
          best = entry.value;
        }
      }
      if (current == null) return null;
      if (current == toAreaId) return best;
      visited.add(current);

      for (final connection in connections) {
        String? next;
        if (connection.fromAreaId == current) {
          next = connection.toAreaId;
        } else if (connection.bidirectional && connection.toAreaId == current) {
          next = connection.fromAreaId;
        }
        if (next == null || connection.minutes <= 0) continue;
        final candidate = best + connection.minutes;
        if (candidate < (distances[next] ?? (1 << 30))) {
          distances[next] = candidate;
        }
      }
    }
  }


  _NextFacilityDecision _selectNextWaitAwareFacility({
    required List<ScheduleItem> scheduledItems,
    required List<Facility> allFacilities,
    required List<Facility> remainingFacilities,
    required List<Facility> routeOrder,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required int currentMinutes,
    required String? previousAreaId,
    required List<EventImpact> eventImpacts,
    required TripSettings settings,
    required Map<String, double> morningScores,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<ExpertRecommendationProfile> expertProfiles,
    required DateTime targetDate,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
    required List<String> committedOpeningFacilityIds,
  }) {
    if (committedOpeningFacilityIds.isNotEmpty) {
      final committedId = committedOpeningFacilityIds.first;
      for (final facility in remainingFacilities) {
        if (facility.id == committedId) {
          return _NextFacilityDecision(
            facility: facility,
            reason: '朝一ルート比較で選んだ後続施設として配置しました。',
            isOpeningStrategy: true,
          );
        }
      }
      committedOpeningFacilityIds.clear();
    }

    if (remainingFacilities.length == 1) {
      return _NextFacilityDecision(facility: remainingFacilities.single);
    }

    if (_waitTimeBandForMinutes(currentMinutes) == WaitTimeBand.afterOpening) {
      final openingDecision = _selectOpeningSequenceFirstFacility(
        remainingFacilities: remainingFacilities,
        preferences: preferences,
        waitProfiles: waitProfiles,
        currentMinutes: currentMinutes,
        previousAreaId: previousAreaId,
        eventImpacts: eventImpacts,
        settings: settings,
        morningScores: morningScores,
        areaConnections: areaConnections,
        facilityLocationById: facilityLocationById,
        expertProfiles: expertProfiles,
        targetDate: targetDate,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );
      if (openingDecision != null) {
        return _NextFacilityDecision(
          facility: openingDecision.facility,
          reason: openingDecision.reason,
          isOpeningStrategy: true,
          openingSequenceFacilityIds: openingDecision.sequenceFacilityIds,
        );
      }
    }

    final scored = <_WaitAwareCandidate>[];
    for (final facility in remainingFacilities) {
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      final preferredTime =
          preference?.preferredTime ?? PreferredTime.anytime;
      final allocation = timeAllocator.allocate(
        settings: settings,
        preferredTime: preferredTime,
      );
      final preferredStartMinutes = _toMinutes(
        allocation.startHour,
        allocation.startMinute,
      );
      final movementMinutes = _calculateMovementMinutes(
        previousAreaId: previousAreaId,
        currentAreaId: facilityLocationById[facility.id]?.areaId ?? facility.areaId,
        atMinutes: currentMinutes,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );
      final candidateStart = _maximum(
        currentMinutes + movementMinutes,
        preferredStartMinutes,
      );

      final routeIndex = routeOrder.indexOf(facility);
      final preferenceValue =
          (preference?.priority.value ?? facility.priority.value).toDouble();
      final timing = _waitTimingOpportunity(
        facility: facility,
        preference: preference,
        waitProfiles: waitProfiles,
        scheduledStartMinutes: candidateStart,
        settings: settings,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      );

      // Data-driven total-time cost. Preference remains a tie-break/value
      // signal, but the schedule is not primarily selected by low/mid/high.
      // Movement + waiting + experience + opportunity loss are all expressed
      // in minutes so a small wait saving cannot justify a large park crossing.
      final currentEstimate = _resolveWaitEstimate(
        facility: facility,
        preference: preference,
        waitProfiles: waitProfiles,
        scheduledStartMinutes: candidateStart,
        settings: settings,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );
      final conditionalWaitDecision = _evaluateResolvedAttractionWaitTolerance(
        facility: facility,
        preference: preference,
        waitEstimate: currentEstimate,
      );
      final experienceMinutes = _resolveFacilityDuration(facility);
      final expert = expertRecommendationService.evaluate(
        facility: facility,
        targetDate: targetDate,
        profiles: expertProfiles,
        preference: preference,
        waitProfiles: waitProfiles,
      );
      final startDelay = _maximum(0, candidateStart - currentMinutes - movementMinutes);
      final opportunityCost = timing == null
          ? 0.0
          : -timing.delayPenaltyMinutes.toDouble();
      final anchorImpact = _futureScheduledAnchorImpact(
        facility: facility,
        candidateStartMinutes: candidateStart,
        candidateDurationMinutes:
            currentEstimate.waitMinutes + experienceMinutes,
        scheduledItems: scheduledItems,
        facilities: allFacilities,
        facilityLocationById: facilityLocationById,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );
      final totalTimeCost = movementMinutes.toDouble() +
          currentEstimate.waitMinutes +
          experienceMinutes +
          startDelay +
          opportunityCost +
          anchorImpact.movementMinutes * 0.8;

      var score = -totalTimeCost;
      if (!anchorImpact.fitsBeforeAnchor) {
        // Do not consume the slot immediately before a meal/fixed facility if
        // doing so would make the anchor unreachable. Other candidates that
        // fit the local area should win this iteration instead.
        score -= 500.0;
      }
      score += preferenceValue * 2.0;
      score += expert.score * 0.16;

      // Coverage rescue: a wish that is expensive to fit later must not lose
      // merely because a shorter/easier facility is locally cheaper now.
      // This is intentionally data-driven (daily standby difficulty), not a
      // facility-name special case. It helps the forward pass reserve enough
      // room for high-demand wishes before fixed meals/shows fragment the day.
      final dayDifficultyMinutes = _openingDayDifficultyMinutes(
        facility: facility,
        waitProfiles: waitProfiles,
        greetingWaitPlanning: greetingWaitPlanning,
      );
      final coverageDifficultyBonus =
          dayDifficultyMinutes.clamp(0, 150).toDouble() * 0.55;
      score += coverageDifficultyBonus;

      score -= (routeIndex < 0 ? routeOrder.length : routeIndex) * 0.5;

      final openingScore = morningScores[facility.id];
      if (openingScore != null) {
        // 朝一専用スコアは上位2件の固定配置には使わず、
        // 全候補を毎回比較する補助点としてのみ使う。
        score += openingScore.clamp(-20.0, 100.0).toDouble() * 0.25;
      }



      final spreadOpportunity = _waitProfileSpreadOpportunity(
        facility: facility,
        waitProfiles: waitProfiles,
        scheduledStartMinutes: candidateStart,
      );

      scored.add(
        _WaitAwareCandidate(
          facility: facility,
          score: score,
          timing: timing,
          expertScore: expert.score,
          expertReason: expert.reason,
          waitSpreadMinutes: spreadOpportunity.spreadMinutes,
          cheapWindowCaptureMinutes:
              spreadOpportunity.cheapWindowCaptureMinutes,
          conditionalWaitSatisfied: !conditionalWaitDecision.shouldSkip,
        ),
      );
    }

    scored.sort((a, b) {
      // A conditional `できれば` wish that is currently above its wait
      // threshold yields to candidates whose conditions are currently met.
      // This is an ordering guard, not a change to optimizer score weights.
      final conditionCompare = (b.conditionalWaitSatisfied ? 1 : 0)
          .compareTo(a.conditionalWaitSatisfied ? 1 : 0);
      if (conditionCompare != 0) return conditionCompare;

      // Protect the most valuable cheap window first. A facility with a large
      // reliable day-wide wait spread wins only while the current band is
      // actually cheap; once its queue is already near the daily high, the
      // existing total-time/anchor evaluation decides instead.
      final captureCompare =
          b.cheapWindowCaptureMinutes.compareTo(a.cheapWindowCaptureMinutes);
      if (captureCompare != 0) return captureCompare;
      final spreadCompare = b.waitSpreadMinutes.compareTo(a.waitSpreadMinutes);
      if (spreadCompare != 0) return spreadCompare;
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return routeOrder.indexOf(a.facility).compareTo(
            routeOrder.indexOf(b.facility),
          );
    });

    final best = scored.first;
    final timing = best.timing;
    String? reason;
    if (timing != null && timing.delayPenaltyMinutes >= 15) {
      reason =
          'この時間帯を逃すと、同施設の信頼できる後続時間帯より'
          '待ち時間が約${timing.delayPenaltyMinutes}分増える見込みのため、'
          '現在の利用を優先しました。';
    } else if (timing != null && timing.delayPenaltyMinutes <= -15) {
      // This can still be selected because priority / route / preferred-time
      // constraints outweigh the future saving. Explain only when it wins.
      reason =
          '後の時間帯に約${-timing.delayPenaltyMinutes}分短い実績がありますが、'
          '優先度・移動・希望時間を合わせて現在の配置を選びました。';
    }
    if (best.expertScore >= 75) {
      final expertText =
          'Disney通おすすめ評価${best.expertScore.toStringAsFixed(1)}点（${best.expertReason}）を加味しました。';
      reason = reason == null ? expertText : '$reason $expertText';
    }

    return _NextFacilityDecision(
      facility: best.facility,
      reason: reason,
    );
  }

  _OpeningSequenceDecision? _selectOpeningSequenceFirstFacility({
    required List<Facility> remainingFacilities,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required int currentMinutes,
    required String? previousAreaId,
    required List<EventImpact> eventImpacts,
    required TripSettings settings,
    required Map<String, double> morningScores,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<ExpertRecommendationProfile> expertProfiles,
    required DateTime targetDate,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final queueCandidates = remainingFacilities.where((facility) {
      if (!_usesQueueWaitPlanning(facility)) return false;
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      final preferredTime = preference?.preferredTime ?? PreferredTime.anytime;
      return preferredTime == PreferredTime.anytime ||
          preferredTime == PreferredTime.morning;
    }).toList(growable: false);
    if (queueCandidates.isEmpty) return null;

    _OpeningSequence? best;
    for (final first in queueCandidates) {
      final sequence = _buildOpeningSequence(
        first: first,
        candidates: queueCandidates,
        preferences: preferences,
        waitProfiles: waitProfiles,
        startMinutes: currentMinutes,
        previousAreaId: previousAreaId,
        eventImpacts: eventImpacts,
        settings: settings,
        morningScores: morningScores,
        areaConnections: areaConnections,
        facilityLocationById: facilityLocationById,
        expertProfiles: expertProfiles,
        targetDate: targetDate,
        unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        greetingWaitPlanning: greetingWaitPlanning,
      );
      if (best == null || sequence.score > best.score) {
        best = sequence;
      }
    }
    if (best == null || best.facilities.isEmpty) return null;

    final first = best.facilities.first;
    final detail = best.firstStep;
    final route = best.facilities.map((facility) => facility.name).join(' → ');
    final alternative = detail.alternativeAccessPenalty > 0
        ? ' DPA/シングルライダー等で後から短縮できる可能性を'
            '${detail.alternativeAccessPenalty.round()}分相当減点しました。'
        : '';
    final hasReliableOpeningProfile = _hasReliableWaitProfile(
      facilityId: first.id,
      waitProfiles: waitProfiles,
    );
    final difficulty = detail.dayDifficultyMinutes > 0
        ? first.category == FacilityCategory.greeting &&
                !hasReliableOpeningProfile
            ? ' グリーティング待ち時間は実測未取得のため、'
                '計画用暫定値${detail.dayDifficultyMinutes}分を安全側の評価に使用しました。'
            : ' 一日を通した通常待機難易度は最大約'
                '${detail.dayDifficultyMinutes}分として評価しました。'
        : '';
    final transport = detail.transportPenalty > 0
        ? ' 移動型施設のため朝一枠の占有を'
            '${detail.transportPenalty.round()}分相当減点しました。'
        : '';
    final expertReason = detail.expertScore >= 60
        ? ' Disney通おすすめ評価${detail.expertScore.toStringAsFixed(1)}点（${detail.expertReason}）を加味しました。'
        : '';
    final deferReason = detail.deferLossMinutes >= 15
        ? ' この時間帯を逃すと、近い後続時間帯より待ち時間が約${detail.deferLossMinutes}分増える見込みです。'
        : detail.deferLossMinutes <= -15
            ? ' 開園直後は後続時間帯より約${-detail.deferLossMinutes}分混む実績のため、朝一集中を減点しています。'
            : '';
    final openingWaitLabel = _usesUnlimitedRideBenefit(
      facility: first,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    )
        ? '優先入口利用バッファ${detail.waitMinutes}分'
        : '待ち${detail.waitMinutes}分';

    final usesUnlimitedRide = _usesUnlimitedRideBenefit(
      facility: first,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    );
    final greetingPlan = greetingWaitPlanning[first.id];
    final birthdaySummary = greetingPlan?.isCharacterBirthday == true
        ? ' ${greetingPlan!.birthdayCharacterNames.join('・')}の記念日のため特殊混雑日として扱い、'
            '計画待ち${greetingPlan.birthdayPlanningWaitMinutes}分を確保しています。'
            '${greetingPlan.birthdayExtremeRiskMinutes}分級を極端混雑リスクとして別管理しています。'
        : '';
    final strategySummary = usesUnlimitedRide
        ? '乗り放題対象は後からも優先入口を利用できるため朝一緊急性を抑え、'
            '対象外施設の通常待ち悪化との機会費用も比較しています。'
            '施設価値・移動効率・優先入口利用バッファ・後続ルートは維持して評価しています。'
        : unlimitedRideBufferMinutes.isNotEmpty
            ? '乗り放題対象外のため、後から短縮しにくい通常待ち時間と'
                '後回し損失を乗り放題対象施設より重視しています。'
            : detail.deferLossMinutes >= 15
                ? '朝は単なる短待ち施設ではなく、一日を通して攻略困難で'
                    '後回し損失が大きい施設を優先しています。'
                : '朝は後回し損失だけでなく、一日を通した通常待機難易度・'
                    '移動・体験時間・後続ルートを合わせて比較しています。';

    return _OpeningSequenceDecision(
      facility: first,
      sequenceFacilityIds: best.facilities.map((facility) => facility.id).toList(growable: false),
      reason:
          '${best.facilities.length >= 2 ? '朝一は最初の${best.facilities.length}手をルートとして比較しました。' : '朝一候補を比較しました。'}'
          '候補ルート「$route」を総合評価し、'
          '候補評価時点では$openingWaitLabel、'
          '後回し損失${detail.deferLossMinutes >= 0 ? '+' : ''}${detail.deferLossMinutes}分、'
          '移動${detail.movementMinutes}分として評価しました。'
          '$deferReason'
          '$difficulty'
          '$alternative'
          '$transport'
          '$expertReason'
          '$birthdaySummary'
          '$strategySummary',
    );
  }

  _OpeningSequence _buildOpeningSequence({
    required Facility first,
    required List<Facility> candidates,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required int startMinutes,
    required String? previousAreaId,
    required List<EventImpact> eventImpacts,
    required TripSettings settings,
    required Map<String, double> morningScores,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<ExpertRecommendationProfile> expertProfiles,
    required DateTime targetDate,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    const maxDepth = 3;
    const discounts = <double>[1.0, 0.65, 0.4];
    final selected = <Facility>[];
    final remaining = [...candidates];
    var current = startMinutes;
    var areaId = previousAreaId;
    var score = 0.0;
    _OpeningStepEvaluation? firstStep;
    Facility? forced = first;

    for (var depth = 0; depth < maxDepth && remaining.isNotEmpty; depth++) {
      Facility? chosen;
      _OpeningStepEvaluation? chosenEvaluation;
      var chosenScore = -double.infinity;
      final pool = forced == null ? remaining : <Facility>[forced];

      for (final facility in pool) {
        final evaluation = _evaluateOpeningStep(
          facility: facility,
          preferences: preferences,
          waitProfiles: waitProfiles,
          currentMinutes: current,
          previousAreaId: areaId,
          eventImpacts: eventImpacts,
          settings: settings,
          morningScores: morningScores,
          areaConnections: areaConnections,
          facilityLocationById: facilityLocationById,
          expertProfiles: expertProfiles,
          targetDate: targetDate,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
          greetingWaitPlanning: greetingWaitPlanning,
        );
        if (evaluation.score > chosenScore) {
          chosen = facility;
          chosenEvaluation = evaluation;
          chosenScore = evaluation.score;
        }
      }
      if (chosen == null || chosenEvaluation == null) break;

      selected.add(chosen);
      remaining.remove(chosen);
      firstStep ??= chosenEvaluation;
      score += chosenEvaluation.score * discounts[depth];
      current += chosenEvaluation.movementMinutes +
          chosenEvaluation.waitMinutes +
          _resolveFacilityDuration(chosen);
      areaId =
          facilityLocationById[chosen.id]?.effectiveExitAreaId ??
          chosen.areaId;
      forced = null;

      // Opening optimization is only meaningful while the simulated route is
      // still in the historical opening band. Do not force a three-step route
      // deep into late morning if long queues consume the whole phase.
      if (_waitTimeBandForMinutes(current) != WaitTimeBand.afterOpening) break;
    }

    return _OpeningSequence(
      facilities: List.unmodifiable(selected),
      score: score,
      firstStep: firstStep ?? const _OpeningStepEvaluation.empty(),
    );
  }

  _OpeningStepEvaluation _evaluateOpeningStep({
    required Facility facility,
    required List<PlanPreference> preferences,
    required List<TimeBandWaitProfile> waitProfiles,
    required int currentMinutes,
    required String? previousAreaId,
    required List<EventImpact> eventImpacts,
    required TripSettings settings,
    required Map<String, double> morningScores,
    required List<AreaConnection> areaConnections,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<ExpertRecommendationProfile> expertProfiles,
    required DateTime targetDate,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final preference = _findPreference(
      facilityId: facility.id,
      preferences: preferences,
    );
    final movementMinutes = _calculateMovementMinutes(
      previousAreaId: previousAreaId,
      currentAreaId: facilityLocationById[facility.id]?.areaId ?? facility.areaId,
      atMinutes: currentMinutes,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );
    final candidateStart = currentMinutes + movementMinutes;
    final waitEstimate = _resolveWaitEstimate(
      facility: facility,
      preference: preference,
      waitProfiles: waitProfiles,
      scheduledStartMinutes: candidateStart,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      greetingWaitPlanning: greetingWaitPlanning,
    );
    final timing = _waitTimingOpportunity(
      facility: facility,
      preference: preference,
      waitProfiles: waitProfiles,
      scheduledStartMinutes: candidateStart,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
      openingOpportunity: true,
    );
    final priority = preference?.priority.value ?? facility.priority.value;
    final morningSignal = morningScores[facility.id] ?? 0.0;
    final alternativeAccessPenalty = _openingAlternativeAccessPenalty(
      facility: facility,
      preference: preference,
      settings: settings,
    );
    final isUnlimitedRide =
        unlimitedRideBufferMinutes.containsKey(facility.id);
    final dayDifficultyMinutes = isUnlimitedRide
        ? 0
        : _openingDayDifficultyMinutes(
            facility: facility,
            waitProfiles: waitProfiles,
            greetingWaitPlanning: greetingWaitPlanning,
          );
    // Some historical profiles do not have a reliable adjacent time-band
    // comparison, which used to collapse the opening defer-loss to zero.
    // For opening strategy only, fall back to the gap between the day's
    // normal standby difficulty and the current opening estimate. This keeps
    // high-demand attractions from being incorrectly treated as safe to defer.
    final profileDeferLoss = timing?.delayPenaltyMinutes;
    final difficultyFallback =
        (dayDifficultyMinutes - waitEstimate.waitMinutes).clamp(-120, 120);
    final deferLoss = profileDeferLoss == null
        ? difficultyFallback
        : profileDeferLoss >= difficultyFallback
            ? profileDeferLoss
            : difficultyFallback;

    final transportPenalty = _openingTransportPenalty(
      facility: facility,
      preference: preference,
      location: facilityLocationById[facility.id],
    );
    final expert = expertRecommendationService.evaluate(
      facility: facility,
      targetDate: targetDate,
      profiles: expertProfiles,
      preference: preference,
      waitProfiles: waitProfiles,
    );
    final greetingPlan = greetingWaitPlanning[facility.id];

    // Opening is intentionally opportunity-cost dominant. A ride that is only
    // 5 minutes shorter now should not beat a ride that will become 40-60
    // minutes worse after the opening window. Negative deferLoss represents an
    // opening rush and directly pushes that attraction later.
    var score = 0.0;
    score += deferLoss * 2.2;
    score += priority * 8.0;
    score += expert.score * 0.45;
    score += dayDifficultyMinutes * 1.25;
    score += morningSignal.clamp(-60.0, 120.0).toDouble() * 0.35;

    // In an unlimited-ride plan, covered attractions remain cheap to access
    // later in the day. Preserve their experience value, but add an explicit
    // opportunity-cost preference for uncovered attractions whose standby
    // conditions are expected to worsen. This is data-driven: the bonus comes
    // from the measured defer loss/day difficulty, not from facility names.
    if (unlimitedRideBufferMinutes.isNotEmpty) {
      if (!isUnlimitedRide) {
        // When some selected attractions can be ridden later with priority
        // access, scarce opening time is more valuable for uncovered
        // attractions whose standby cost grows. Use measured wait-profile
        // opportunity cost rather than a facility-name or fixed-ID bonus.
        final uncoveredOpportunityBonus =
            (deferLoss.clamp(0, 60) * 1.25) +
            (dayDifficultyMinutes.clamp(0, 120) * 0.22);
        score += uncoveredOpportunityBonus;
      } else {
        // Covered attractions keep their experience/route value, but their
        // opening slot has a real opportunity cost because the same priority
        // access remains available later. This prevents several covered rides
        // from consuming all of the first moves solely on experience score.
        final deferrableAccessPenalty =
            (expert.score.clamp(0, 100) * 0.18) +
            (waitEstimate.waitMinutes.clamp(0, 30) * 0.20);
        score -= deferrableAccessPenalty;
      }
    }

    score -= waitEstimate.waitMinutes * 0.70;
    // Spending most of the opening window in a queue has a large opportunity
    // cost even for a popular attraction. Apply a data-driven congestion-trap
    // penalty above 60 minutes instead of hard-coding any facility name.
    final openingCongestionTrapMinutes =
        (waitEstimate.waitMinutes - 60).clamp(0, 120);
    score -= openingCongestionTrapMinutes * 1.25;
    score -= movementMinutes * 1.25;
    score -= _resolveFacilityDuration(facility) * 0.15;
    score -= alternativeAccessPenalty;
    score -= transportPenalty;
    if (greetingPlan?.isCharacterBirthday == true) {
      score += greetingPlan!.birthdayOpeningUrgencyBonus;
    }

    if (preference?.preferredTime == PreferredTime.morning) score += 18;
    if (facility.isSeasonal) score += 8;

    final explainedMovementMinutes = previousAreaId == null
        ? EntryPredictionService.gateToFirstFacilityMinutes
        : movementMinutes;

    return _OpeningStepEvaluation(
      score: score,
      waitMinutes: waitEstimate.waitMinutes,
      movementMinutes: explainedMovementMinutes,
      deferLossMinutes: deferLoss,
      alternativeAccessPenalty: alternativeAccessPenalty,
      dayDifficultyMinutes: dayDifficultyMinutes,
      transportPenalty: transportPenalty,
      expertScore: expert.score,
      expertReason: expert.reason,
    );
  }

  int _openingDayDifficultyMinutes({
    required Facility facility,
    required List<TimeBandWaitProfile> waitProfiles,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    TimeBandWaitProfile? profile;
    for (final item in waitProfiles) {
      if (item.facilityId == facility.id && item.parkId == facility.parkId) {
        profile = item;
        break;
      }
    }
    if (profile == null) {
      return facility.category == FacilityCategory.greeting
          ? (greetingWaitPlanning[facility.id]?.waitMinutes ??
              _fallbackWaitMinutes(facility))
          : 0;
    }

    var maximum = 0;
    for (final range in profile.ranges.values) {
      if (!_isReliableTimingRange(range)) continue;
      if (range.typicalMinutes > maximum) {
        maximum = range.typicalMinutes;
      }
    }
    return maximum;
  }

  double _openingTransportPenalty({
    required Facility facility,
    required PlanPreference? preference,
    required FacilityLocation? location,
  }) {
    if (facility.rideType?.trim().toLowerCase() != 'transportation') {
      return 0;
    }
    if (preference?.preferredTime == PreferredTime.morning) return 0;
    if ((preference?.priority.value ?? facility.priority.value) >= 4) return 0;

    return (location?.hasAmbiguousExit ?? false) ? 28.0 : 16.0;
  }

  double _openingAlternativeAccessPenalty({
    required Facility facility,
    required PlanPreference? preference,
    required TripSettings settings,
  }) {
    if (_usesShortenedQueue(facility: facility, preference: preference)) {
      return 0;
    }

    var penalty = 0.0;
    if (settings.canUseDpa && facility.supportsDpa) {
      penalty = _maximumDouble(penalty, 16.0);
    }
    if (settings.canUsePriorityPass && facility.supportsPriorityPass) {
      penalty = _maximumDouble(penalty, 20.0);
    }
    if (settings.canUseSingleRider && facility.supportsSingleRider) {
      penalty = _maximumDouble(penalty, 14.0);
    }
    return penalty;
  }

  double _maximumDouble(double first, double second) =>
      first >= second ? first : second;

  ({int spreadMinutes, int cheapWindowCaptureMinutes})
      _waitProfileSpreadOpportunity({
    required Facility facility,
    required List<TimeBandWaitProfile> waitProfiles,
    required int scheduledStartMinutes,
  }) {
    TimeBandWaitProfile? profile;
    for (final item in waitProfiles) {
      if (item.facilityId == facility.id && item.parkId == facility.parkId) {
        profile = item;
        break;
      }
    }
    if (profile == null) {
      return (spreadMinutes: 0, cheapWindowCaptureMinutes: 0);
    }

    const bands = <WaitTimeBand>[
      WaitTimeBand.afterOpening,
      WaitTimeBand.beforeLunch,
      WaitTimeBand.afterLunch,
      WaitTimeBand.aroundShows,
      WaitTimeBand.beforeDinner,
      WaitTimeBand.afterDinner,
      WaitTimeBand.beforeClosing,
    ];
    final reliable = <int>[];
    for (final band in bands) {
      final range = profile.rangeFor(band);
      if (_isReliableTimingRange(range)) reliable.add(range!.typicalMinutes);
    }
    if (reliable.length < 2) {
      return (spreadMinutes: 0, cheapWindowCaptureMinutes: 0);
    }
    reliable.sort();
    final minWait = reliable.first;
    final maxWait = reliable.last;
    final currentRange = profile.rangeFor(_waitTimeBandForMinutes(scheduledStartMinutes));
    if (!_isReliableTimingRange(currentRange)) {
      return (spreadMinutes: maxWait - minWait, cheapWindowCaptureMinutes: 0);
    }

    // The spread tells us how costly it can be to miss this attraction's good
    // window. Capture is high only while the current band is still cheap. This
    // avoids blindly prioritising a volatile attraction while it is already at
    // its expensive part of the day.
    final currentWait = currentRange!.typicalMinutes;
    return (
      spreadMinutes: maxWait - minWait,
      cheapWindowCaptureMinutes: (maxWait - currentWait).clamp(0, 240),
    );
  }

  _WaitTimingOpportunity? _waitTimingOpportunity({
    required Facility facility,
    required PlanPreference? preference,
    required List<TimeBandWaitProfile> waitProfiles,
    required int scheduledStartMinutes,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
    bool openingOpportunity = false,
  }) {
    if (!_usesQueueWaitPlanning(facility) ||
        facility.waitTime != null ||
        _usesShortenedQueue(facility: facility, preference: preference) ||
        _usesUnlimitedRideBenefit(
          facility: facility,
          settings: settings,
          unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
        )) {
      return null;
    }

    TimeBandWaitProfile? profile;
    for (final item in waitProfiles) {
      if (item.facilityId == facility.id && item.parkId == facility.parkId) {
        profile = item;
        break;
      }
    }
    if (profile == null) return null;

    const orderedBands = <WaitTimeBand>[
      WaitTimeBand.afterOpening,
      WaitTimeBand.beforeLunch,
      WaitTimeBand.afterLunch,
      WaitTimeBand.aroundShows,
      WaitTimeBand.beforeDinner,
      WaitTimeBand.afterDinner,
      WaitTimeBand.beforeClosing,
    ];
    final currentBand = _waitTimeBandForMinutes(scheduledStartMinutes);
    final currentIndex = orderedBands.indexOf(currentBand);
    if (currentIndex < 0) return null;

    final currentRange = profile.rangeFor(currentBand);
    if (!_isReliableTimingRange(currentRange)) {
      return null;
    }

    // Opening and the rest of the day intentionally answer different
    // questions. At opening, compare the next two reliable bands and protect
    // the attraction whose cheap opening window is easiest to lose. After the
    // opening decision, use rolling opportunity cost: scan every reliable
    // remaining band and ask whether the attraction can be recovered more
    // cheaply later. This avoids spending the current slot on a facility that
    // becomes busy at lunch but reliably drops again in the evening.
    const openingLookAheadReliableBands = 2;
    final futureCandidates = <({WaitTimeBand band, int waitMinutes})>[];
    for (var index = currentIndex + 1; index < orderedBands.length; index++) {
      final band = orderedBands[index];
      final range = profile.rangeFor(band);
      if (!_isReliableTimingRange(range)) continue;
      futureCandidates.add((
        band: band,
        waitMinutes: range!.typicalMinutes,
      ));
      if (openingOpportunity &&
          futureCandidates.length >= openingLookAheadReliableBands) {
        break;
      }
    }

    if (futureCandidates.isEmpty) {
      return null;
    }

    var representativeFuture = futureCandidates.first;
    for (final candidate in futureCandidates.skip(1)) {
      final shouldReplace = openingOpportunity
          ? candidate.waitMinutes > representativeFuture.waitMinutes
          : candidate.waitMinutes < representativeFuture.waitMinutes;
      if (shouldReplace) {
        representativeFuture = candidate;
      }
    }

    return _WaitTimingOpportunity(
      currentBand: currentBand,
      currentWaitMinutes: currentRange!.typicalMinutes,
      bestFutureBand: representativeFuture.band,
      bestFutureWaitMinutes: representativeFuture.waitMinutes,
      delayPenaltyMinutes:
          representativeFuture.waitMinutes - currentRange.typicalMinutes,
    );
  }

  bool _isReliableTimingRange(WaitTimeRange? range) {
    if (range == null || range.typicalMinutes <= 0) return false;
    // v7.5.0 ordering decisions are stricter than display-only estimates.
    // A different ordering can affect the whole day, so thin bands are not
    // allowed to move facilities around.
    return range.sampleCount == null || range.sampleCount! >= 3;
  }

  int _applyFacilitySpecificStartPriority({
    required Facility facility,
    required PlanPreference? preference,
    required int requestedStartMinutes,
    required int entryMinutes,
    required int currentMinutes,
    required int movementMinutes,
  }) {
    if (facility.isCapsuleToy && preference?.prioritizeCapsuleToy == true) {
      return _maximum(entryMinutes, currentMinutes + movementMinutes);
    }

    return requestedStartMinutes;
  }

  int _resolveFacilityDuration(Facility facility) {
    final configuredDuration = facility.durationMinutes;

    if (configuredDuration > 0) {
      return configuredDuration;
    }

    if (facility.isRestaurant) {
      return facility.restaurantType.defaultDurationMinutes;
    }

    if (facility.isShop) {
      return facility.shopType.defaultDurationMinutes;
    }

    return 60;
  }

  bool _usesQueueWaitPlanning(Facility facility) {
    return facility.category == FacilityCategory.attraction ||
        facility.category == FacilityCategory.greeting;
  }

  bool _usesUnlimitedRideBenefit({
    required Facility facility,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
  }) {
    return settings.usesVacationPackage &&
        settings.hasUnlimitedAttractionRides &&
        facility.category == FacilityCategory.attraction &&
        unlimitedRideBufferMinutes.containsKey(facility.id);
  }

  int? _priorityAccessBufferMinutes({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    final method = preference?.accessMethod ?? FacilityAccessMethod.standby;
    if (method == FacilityAccessMethod.dpa && facility.supportsDpa) return 10;
    if (method == FacilityAccessMethod.priorityPass &&
        facility.supportsPriorityPass) {
      return 15;
    }
    if (method == FacilityAccessMethod.standbyPass &&
        facility.supportsStandbyPass) {
      return 20;
    }
    if (preference?.useDpa == true && facility.supportsDpa) return 10;
    if (preference?.usePriorityPass == true &&
        facility.supportsPriorityPass) {
      return 15;
    }
    if (preference?.useStandbyPass == true && facility.supportsStandbyPass) {
      return 20;
    }
    return null;
  }

  bool _usesShortenedQueue({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    return _priorityAccessBufferMinutes(
          facility: facility,
          preference: preference,
        ) !=
        null;
  }

  int _resolvePlannedFacilityDuration({
    required Facility facility,
    required PlanPreference? preference,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
    _WaitEstimate? waitEstimate,
  }) {
    final experienceMinutes = _resolveFacilityDuration(facility);

    if (!_usesQueueWaitPlanning(facility)) {
      return experienceMinutes;
    }

    final usesUnlimitedRide = _usesUnlimitedRideBenefit(
      facility: facility,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    );
    if (usesUnlimitedRide) {
      final bufferMinutes = unlimitedRideBufferMinutes[facility.id] ?? 15;
      return experienceMinutes + bufferMinutes;
    }

    // DPA等でも入場から乗車までの時間は0分ではないため、
    // 最低限のキュー・乗降バッファを確保する。
    final priorityAccessBuffer = _priorityAccessBufferMinutes(
      facility: facility,
      preference: preference,
    );
    if (priorityAccessBuffer != null) {
      return experienceMinutes + priorityAccessBuffer;
    }

    return experienceMinutes +
        (waitEstimate?.waitMinutes ?? _fallbackWaitMinutes(facility));
  }

  _WaitEstimate _resolveWaitEstimate({
    required Facility facility,
    required PlanPreference? preference,
    required List<TimeBandWaitProfile> waitProfiles,
    required int scheduledStartMinutes,
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final method = preference?.accessMethod ?? FacilityAccessMethod.standby;
    final usesUnlimitedRide = _usesUnlimitedRideBenefit(
      facility: facility,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    );
    if (usesUnlimitedRide) {
      final bufferMinutes = unlimitedRideBufferMinutes[facility.id] ?? 15;
      return _WaitEstimate(
        waitMinutes: bufferMinutes,
        source: 'バケーションパッケージ乗り放題（優先入口利用バッファ$bufferMinutes分・Disney Planner計画値）',
        isPriorityAccessBuffer: true,
      );
    }

    final priorityAccessBuffer = _priorityAccessBufferMinutes(
      facility: facility,
      preference: preference,
    );

    if (priorityAccessBuffer != null) {
      return _WaitEstimate(
        waitMinutes: priorityAccessBuffer,
        source:
            '${method.label}（優先利用バッファ$priorityAccessBuffer分・Disney Planner計画値）',
        isPriorityAccessBuffer: true,
      );
    }

    if (facility.waitTime != null) {
      return _WaitEstimate(
        waitMinutes: timeRoundingService.ceilMinutes(facility.waitTime!.minutes),
        source: '施設の待ち時間データ（5分単位切り上げ）',
      );
    }

    TimeBandWaitProfile? profile;
    for (final item in waitProfiles) {
      if (item.facilityId == facility.id && item.parkId == facility.parkId) {
        profile = item;
        break;
      }
    }

    if (profile != null) {
      final band = _waitTimeBandForMinutes(scheduledStartMinutes);
      final range = profile.rangeFor(band);

      // HistoricalWaitProfileGenerator はサンプルが無い時間帯を
      // 0/0/0として保持する。これを「待ち時間0分」と誤認しない。
      if (_isReliableTimingRange(range)) {
        return _WaitEstimate(
          waitMinutes: timeRoundingService.ceilMinutes(range!.typicalMinutes),
          source:
              '実績待ち時間プロファイル（${band.label}、${profile.source}、時間帯サンプル${range.sampleCount ?? profile.sampleCount}件）',
        );
      }

      // 対象帯だけ観測が無い場合は、同じ施設の最も近い時間帯の
      // 実績を参照する。施設全体に有効実績が無い場合は補完せず、
      // 従来の安全側フォールバックへ戻す。
      final nearest = _nearestValidWaitRange(profile: profile, targetBand: band);
      if (nearest != null) {
        return _WaitEstimate(
          waitMinutes: timeRoundingService.ceilMinutes(nearest.range.typicalMinutes),
          source:
              '実績待ち時間プロファイル（${band.label}を${nearest.band.label}から近接参照、${profile.source}、時間帯サンプル${nearest.range.sampleCount ?? profile.sampleCount}件）',
        );
      }
    }

    final greetingPlan = greetingWaitPlanning[facility.id];
    if (facility.category == FacilityCategory.greeting && greetingPlan != null) {
      return _WaitEstimate(
        waitMinutes: timeRoundingService.ceilMinutes(greetingPlan.waitMinutes),
        source: greetingPlan.source,
      );
    }

    return _WaitEstimate(
      waitMinutes: timeRoundingService.ceilMinutes(_fallbackWaitMinutes(facility)),
      source: facility.category == FacilityCategory.greeting
          ? 'グリーティング待ち時間の実測データ未取得のためDisney Planner計画用暫定値（実測値ではありません）'
          : '待ち時間データ未登録のため優先度別の安全側暫定値',
    );
  }


  _NearestWaitRange? _nearestValidWaitRange({
    required TimeBandWaitProfile profile,
    required WaitTimeBand targetBand,
  }) {
    const orderedBands = <WaitTimeBand>[
      WaitTimeBand.afterOpening,
      WaitTimeBand.beforeLunch,
      WaitTimeBand.afterLunch,
      WaitTimeBand.aroundShows,
      WaitTimeBand.beforeDinner,
      WaitTimeBand.afterDinner,
      WaitTimeBand.beforeClosing,
    ];

    final targetIndex = orderedBands.indexOf(targetBand);
    if (targetIndex < 0) return null;

    _NearestWaitRange? best;
    var bestDistance = orderedBands.length + 1;

    for (var index = 0; index < orderedBands.length; index++) {
      final band = orderedBands[index];
      final range = profile.rangeFor(band);
      if (range == null || range.typicalMinutes <= 0) continue;

      // 近接時間帯は別時間帯からの外挿なので、薄い実績は採用しない。
      // 現行の施設×時間帯サンプル数の中央値が約3件のため3件を最低条件とする。
      // legacy profileではsampleCountがnullなので、再生成までは従来挙動を維持する。
      if (range.sampleCount != null && range.sampleCount! < 3) continue;

      final distance = (index - targetIndex).abs();
      if (distance < bestDistance ||
          (distance == bestDistance &&
              (best == null ||
                  range.typicalMinutes > best.range.typicalMinutes))) {
        best = _NearestWaitRange(band: band, range: range);
        bestDistance = distance;
      }
    }

    return best;
  }

  int _fallbackWaitMinutes(Facility facility) {
    if (facility.category == FacilityCategory.greeting) {
      // Greeting waits are not currently available from the collected live
      // source. Use conservative planning values rather than pretending that
      // missing data means zero wait. These are planner fallbacks, not actual
      // measured waits.
      return switch (facility.priority.name) {
        'highest' => 40,
        'high' => 30,
        'medium' => 25,
        _ => 20,
      };
    }

    return switch (facility.priority.name) {
      'highest' => 60,
      'high' => 45,
      'medium' => 30,
      _ => 20,
    };
  }

  WaitTimeBand _waitTimeBandForMinutes(int minutes) {
    if (minutes < 11 * 60) return WaitTimeBand.afterOpening;
    if (minutes < 12 * 60) return WaitTimeBand.beforeLunch;
    if (minutes < 15 * 60) return WaitTimeBand.afterLunch;
    if (minutes < 17 * 60) return WaitTimeBand.aroundShows;
    if (minutes < 18 * 60) return WaitTimeBand.beforeDinner;
    if (minutes < 20 * 60) return WaitTimeBand.afterDinner;
    return WaitTimeBand.beforeClosing;
  }

  int? _adjustStartForOperatingHours({
    required Facility facility,
    required int requestedStartMinutes,
    required int durationMinutes,
    required int exitMinutes,
    required DateTime targetDate,
  }) {
    final windows = facility.operatingWindowsFor(targetDate);

    if (windows.isEmpty) {
      final fallbackOpenMinutes = _fallbackOpeningMinutes(facility);
      final adjustedStart = fallbackOpenMinutes == null
          ? requestedStartMinutes
          : _maximum(requestedStartMinutes, fallbackOpenMinutes);

      if (adjustedStart + durationMinutes > exitMinutes) {
        return null;
      }

      return adjustedStart;
    }

    final sorted = [...windows]
      ..sort((a, b) => a.open.compareTo(b.open));

    for (final window in sorted) {
      final openMinutes = _toMinutes(window.open.hour, window.open.minute);
      final closeMinutes = _toMinutes(window.close.hour, window.close.minute);
      final adjustedStart = _maximum(requestedStartMinutes, openMinutes);
      final end = adjustedStart + durationMinutes;

      if (end <= closeMinutes && end <= exitMinutes) {
        return adjustedStart;
      }
    }

    return null;
  }

  int? _fallbackOpeningMinutes(Facility facility) {
    // 来園日未設定のデバッグ等では従来互換として10:00を使う。
    // 来園日設定済みの本番プランでは、上流で公式営業時間不明の
    // レストラン・ショップを自動配置対象から除外する。
    if (facility.category == FacilityCategory.restaurant &&
        facility.diningLocationType.name == 'inPark') {
      return _fallbackInParkRestaurantOpenMinutes;
    }

    return null;
  }

  bool _fitsOperatingHours({
    required Facility facility,
    required int startMinutes,
    required int durationMinutes,
    required DateTime targetDate,
  }) {
    final windows = facility.operatingWindowsFor(targetDate);

    if (windows.isEmpty) {
      return true;
    }

    final endMinutes = startMinutes + durationMinutes;

    return windows.any((window) {
      final openMinutes = _toMinutes(window.open.hour, window.open.minute);
      final closeMinutes = _toMinutes(window.close.hour, window.close.minute);
      return startMinutes >= openMinutes && endMinutes <= closeMinutes;
    });
  }

  bool _hasBreakfastTime(TripSettings settings) {
    final entryMinutes = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );

    return entryMinutes < _toMinutes(10, 0);
  }

  _FutureAnchorImpact _futureScheduledAnchorImpact({
    required Facility facility,
    required int candidateStartMinutes,
    required int candidateDurationMinutes,
    required List<ScheduleItem> scheduledItems,
    required List<Facility> facilities,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
  }) {
    ScheduleItem? anchor;
    for (final item in scheduledItems) {
      final facilityId = item.facilityId;
      if (facilityId == null || facilityId.isEmpty) continue;
      final start = _itemStartMinutes(item);
      if (start <= candidateStartMinutes) continue;
      if (start - candidateStartMinutes > 120) continue;
      if (anchor == null || start < _itemStartMinutes(anchor)) {
        anchor = item;
      }
    }
    if (anchor == null) return const _FutureAnchorImpact.none();

    Facility? anchorFacility;
    for (final item in facilities) {
      if (item.id == anchor.facilityId) {
        anchorFacility = item;
        break;
      }
    }
    final anchorAreaId =
        facilityLocationById[anchor.facilityId!]?.areaId ??
        anchorFacility?.areaId;
    if (anchorAreaId == null || anchorAreaId.isEmpty) {
      return const _FutureAnchorImpact.none();
    }

    final candidateExitAreaId =
        facilityLocationById[facility.id]?.effectiveExitAreaId ??
        facility.areaId;
    final candidateEnd = candidateStartMinutes + candidateDurationMinutes;
    final movement = _calculateMovementMinutes(
      previousAreaId: candidateExitAreaId,
      currentAreaId: anchorAreaId,
      atMinutes: candidateEnd,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
    );
    return _FutureAnchorImpact(
      movementMinutes: movement,
      fitsBeforeAnchor: candidateEnd + movement <= _itemStartMinutes(anchor),
    );
  }

  int? _ensureTravelAroundScheduledFacilities({
    required int candidateStartMinutes,
    required int durationMinutes,
    required String targetEntryAreaId,
    required String targetExitAreaId,
    required List<ScheduleItem> items,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<Facility> facilities,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required int exitMinutes,
  }) {
    var candidate = _ensureTravelAfterInterveningFacility(
      candidateStartMinutes: candidateStartMinutes,
      durationMinutes: durationMinutes,
      targetAreaId: targetEntryAreaId,
      items: items,
      facilityLocationById: facilityLocationById,
      facilities: facilities,
      eventImpacts: eventImpacts,
      areaConnections: areaConnections,
      exitMinutes: exitMinutes,
    );

    for (var attempt = 0; candidate != null && attempt < items.length + 2; attempt++) {
      ScheduleItem? nextFacilityItem;
      for (final item in items) {
        final facilityId = item.facilityId;
        if (facilityId == null || facilityId.isEmpty) continue;
        final start = _itemStartMinutes(item);
        if (start <= candidate) continue;
        if (nextFacilityItem == null ||
            start < _itemStartMinutes(nextFacilityItem)) {
          nextFacilityItem = item;
        }
      }
      if (nextFacilityItem == null) return candidate;

      Facility? nextFacility;
      for (final facility in facilities) {
        if (facility.id == nextFacilityItem.facilityId) {
          nextFacility = facility;
          break;
        }
      }
      final nextAreaId =
          facilityLocationById[nextFacilityItem.facilityId!]?.areaId ??
          nextFacility?.areaId;
      if (nextAreaId == null || nextAreaId.isEmpty) return candidate;

      final candidateEnd = candidate + durationMinutes;
      final movementToNext = _calculateMovementMinutes(
        previousAreaId: targetExitAreaId,
        currentAreaId: nextAreaId,
        atMinutes: candidateEnd,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );
      if (candidateEnd + movementToNext <=
          _itemStartMinutes(nextFacilityItem)) {
        return candidate;
      }

      final afterAnchor = _findAvailableStart(
        requestedStartMinutes: _itemEndMinutes(nextFacilityItem),
        durationMinutes: durationMinutes,
        items: items,
        exitMinutes: exitMinutes,
      );
      if (afterAnchor == null) return null;
      candidate = _ensureTravelAfterInterveningFacility(
        candidateStartMinutes: afterAnchor,
        durationMinutes: durationMinutes,
        targetAreaId: targetEntryAreaId,
        items: items,
        facilityLocationById: facilityLocationById,
        facilities: facilities,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
        exitMinutes: exitMinutes,
      );
    }
    return candidate;
  }

  int? _ensureTravelAfterInterveningFacility({
    required int candidateStartMinutes,
    required int durationMinutes,
    required String targetAreaId,
    required List<ScheduleItem> items,
    required Map<String, FacilityLocation> facilityLocationById,
    required List<Facility> facilities,
    required List<EventImpact> eventImpacts,
    required List<AreaConnection> areaConnections,
    required int exitMinutes,
  }) {
    var candidate = candidateStartMinutes;

    for (var attempt = 0; attempt < items.length + 2; attempt++) {
      ScheduleItem? latestFacilityItem;

      for (final item in items) {
        final facilityId = item.facilityId;
        if (facilityId == null || facilityId.isEmpty) continue;
        final itemEnd = _itemEndMinutes(item);
        if (itemEnd > candidate) continue;

        if (latestFacilityItem == null ||
            itemEnd > _itemEndMinutes(latestFacilityItem)) {
          latestFacilityItem = item;
        }
      }

      if (latestFacilityItem == null) {
        return candidate;
      }

      final previousFacilityId = latestFacilityItem.facilityId!;
      Facility? previousFacility;
      for (final facility in facilities) {
        if (facility.id == previousFacilityId) {
          previousFacility = facility;
          break;
        }
      }

      final previousAreaId =
          facilityLocationById[previousFacilityId]?.effectiveExitAreaId ??
          previousFacility?.areaId;
      if (previousAreaId == null || previousAreaId.isEmpty) {
        return candidate;
      }

      final previousEnd = _itemEndMinutes(latestFacilityItem);
      final movementMinutes = _calculateMovementMinutes(
        previousAreaId: previousAreaId,
        currentAreaId: targetAreaId,
        atMinutes: previousEnd,
        eventImpacts: eventImpacts,
        areaConnections: areaConnections,
      );
      final travelReady = previousEnd + movementMinutes;

      if (candidate >= travelReady) {
        return candidate;
      }

      final next = _findAvailableStart(
        requestedStartMinutes: travelReady,
        durationMinutes: durationMinutes,
        items: items,
        exitMinutes: exitMinutes,
      );
      if (next == null) {
        return null;
      }
      if (next == candidate) {
        return candidate;
      }
      candidate = next;
    }

    return candidate;
  }

  int? _findAvailableStart({
    required int requestedStartMinutes,
    required int durationMinutes,
    required List<ScheduleItem> items,
    required int exitMinutes,
  }) {
    var candidateStart = requestedStartMinutes;

    while (candidateStart + durationMinutes <= exitMinutes) {
      ScheduleItem? overlappingItem;

      final sortedItems = List<ScheduleItem>.of(items)
        ..sort((first, second) {
          return _itemStartMinutes(first).compareTo(_itemStartMinutes(second));
        });

      for (final item in sortedItems) {
        final itemStart = _itemStartMinutes(item);

        final itemEnd = _itemEndMinutes(item);

        final protectedItemStart = _protectedStartMinutes(item, itemStart);

        if (_timesOverlap(
          candidateStart,
          candidateStart + durationMinutes,
          protectedItemStart,
          itemEnd,
        )) {
          overlappingItem = item;
          break;
        }
      }

      if (overlappingItem == null) {
        return candidateStart;
      }

      candidateStart = _itemEndMinutes(overlappingItem);
    }

    return null;
  }

  int _protectedStartMinutes(ScheduleItem item, int itemStart) {
    // 確定予定の直前を自由時間として埋めない。
    // 施設間移動・入場待機の最低限の安全余白として15分確保する。
    final isConfirmedFixed = item.id.startsWith('fixed_');
    if (!isConfirmedFixed) return itemStart;
    return _maximum(0, itemStart - 15);
  }

  bool _isTimeRangeAvailable({
    required int startMinutes,
    required int endMinutes,
    required List<ScheduleItem> items,
  }) {
    for (final item in items) {
      if (_timesOverlap(
        startMinutes,
        endMinutes,
        _itemStartMinutes(item),
        _itemEndMinutes(item),
      )) {
        return false;
      }
    }

    return true;
  }

  PlanPreference? _findPreference({
    required String facilityId,
    required List<PlanPreference> preferences,
  }) {
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) {
        return preference;
      }
    }

    return null;
  }

  ScheduleItemType _scheduleTypeForMealSlot(MealSlot slot) {
    return switch (slot) {
      MealSlot.breakfast => ScheduleItemType.breakfast,
      MealSlot.lunch => ScheduleItemType.lunch,
      MealSlot.dinner => ScheduleItemType.dinner,
    };
  }

  String _buildFixedAccessReason({
    required Facility facility,
    required PlanPreference preference,
    required int durationMinutes,
    required bool usesUnlimitedRide,
  }) {
    final isUserPlannedStandby =
        preference.fixedTimeStatus == FixedTimeStatus.planned &&
        preference.accessMethod == FacilityAccessMethod.standby;
    final reasons = <String>[
      if (isUserPlannedStandby)
        'プラン確認画面の空き時間改善でユーザーが選択したため、'
            '「${preference.scheduledAccessTime}」を目標時刻として配置しました。'
      else
        '${_accessMethodShortLabel(preference.accessMethod)}の利用時刻'
            '「${preference.scheduledAccessTime}」へ固定配置しました。',
      if (usesUnlimitedRide)
        'バケーションパッケージ乗り放題対象のため、優先入口利用バッファを含めて計画しています。'
      else
        _accessMethodReason(facility: facility, preference: preference),
      '所要時間を$durationMinutes分として配置しました。',
    ];

    return reasons.where((reason) => reason.isNotEmpty).join(' ');
  }

  String _accessMethodShortLabel(FacilityAccessMethod method) {
    return switch (method) {
      FacilityAccessMethod.standby => '通常利用',
      FacilityAccessMethod.dpa => 'DPA',
      FacilityAccessMethod.priorityPass => 'プライオリティパス',
      FacilityAccessMethod.standbyPass => 'スタンバイパス',
      FacilityAccessMethod.entryRequest => 'エントリー受付',
      FacilityAccessMethod.reservation => '予約利用',
      FacilityAccessMethod.freeSeating => '自由席・自由鑑賞',
    };
  }

  String _buildFixedPerformanceReason({
    required Facility facility,
    required PlanPreference preference,
    required int durationMinutes,
    required _WaitToleranceDecision waitDecision,
  }) {
    final isPlannedEntryRequest =
        preference.fixedTimeStatus == FixedTimeStatus.planned &&
        preference.accessMethod == FacilityAccessMethod.entryRequest;
    final reasons = <String>[
      if (isPlannedEntryRequest)
        'エントリー受付の候補公演時刻'
            '「${preference.preferredPerformanceTime}」へ仮配置しました。'
            '当落確定後に再最適化します。'
      else
        '希望公演時刻'
            '「${preference.preferredPerformanceTime}」へ'
            '固定配置しました。',
    ];

    reasons.add(
      _accessMethodReason(facility: facility, preference: preference),
    );

    if (preference.accessMethod == FacilityAccessMethod.entryRequest) {
      reasons.add(_lotteryFallbackReason(preference.lotteryFallbackAction));
    }

    final waitReason = _buildWaitReason(waitDecision);

    if (waitReason != null) {
      reasons.add(waitReason);
    }

    reasons.add('所要時間を$durationMinutes分として配置しました。');

    return reasons.where((reason) => reason.isNotEmpty).join(' ');
  }

  String _buildMealReason({
    required MealAssignment assignment,
    required PlanPreference? preference,
    required int durationMinutes,
    required _WaitToleranceDecision waitDecision,
    required bool usedReservationTime,
    required bool flexibleMealTimeOptimized,
  }) {
    final facility = assignment.facility;

    final reasons = <String>[];

    if (usedReservationTime && preference != null) {
      reasons.add(
        '予約時刻'
        '「${preference.reservationTime}」へ'
        '固定配置しました。',
      );
    } else {
      reasons.add(assignment.reason);
      if (flexibleMealTimeOptimized) {
        reasons.add(
          '予約で固定されていない食事のため、昼食・夕食の標準的な混雑中心時刻を避ける'
          '10分刻みの可動食事枠として再探索しました。これは実測待ち時間ではなく、'
          '混雑ピークを固定時刻にしないための計画上の安全側ヒューリスティックです。',
        );
      }
    }

    if (facility.isRestaurant) {
      reasons.add(
        'レストラン種別'
        '「${facility.restaurantType.label}」を'
        '考慮しました。',
      );
    }

    if (preference != null) {
      reasons.add(
        _accessMethodReason(facility: facility, preference: preference),
      );
    }

    if (facility.supportsMobileOrder) {
      reasons.add('モバイルオーダー対応施設です。');
    }

    if (facility.supportsPrioritySeating) {
      reasons.add('プライオリティ・シーティング対応施設です。');
    }

    final waitReason = _buildWaitReason(waitDecision);

    if (waitReason != null) {
      reasons.add(waitReason);
    }

    reasons.add('所要時間を$durationMinutes分として配置しました。');

    return reasons.where((reason) => reason.isNotEmpty).join(' ');
  }

  bool _hasReliableWaitProfile({
    required String facilityId,
    required List<TimeBandWaitProfile> waitProfiles,
  }) {
    for (final profile in waitProfiles) {
      if (profile.facilityId != facilityId) continue;
      for (final band in WaitTimeBand.values) {
        if (_isReliableTimingRange(profile.rangeFor(band))) return true;
      }
    }
    return false;
  }

  String? _effectiveDecisionReason({
    required _NextFacilityDecision decision,
    required int requestedStartMinutes,
    required int finalStartMinutes,
  }) {
    final reason = decision.reason;
    if (reason == null || reason.trim().isEmpty) {
      return null;
    }

    // Candidate-selection explanations describe the time at which the
    // candidate was evaluated. Fixed shows, meals, operating hours, or another
    // already-placed item can later push the actual schedule forward. Do not
    // present that stale explanation as though it described the final slot.
    if (finalStartMinutes != requestedStartMinutes) {
      return null;
    }

    if (decision.isOpeningStrategy &&
        _waitTimeBandForMinutes(finalStartMinutes) != WaitTimeBand.afterOpening) {
      return null;
    }

    return reason;
  }

  String _buildReason({
    required Facility facility,
    required PlanPreference? preference,
    required String? previousAreaId,
    required String currentAreaId,
    required int durationMinutes,
    required int scheduledStartMinutes,
    required _WaitToleranceDecision waitDecision,
    String? waitTimingReason,
    List<TimeBandWaitProfile> waitProfiles = const [],
    required TripSettings settings,
    required Map<String, int> unlimitedRideBufferMinutes,
    required Map<String, GreetingWaitPlanningValue> greetingWaitPlanning,
  }) {
    final reasons = <String>[];

    if (previousAreaId == null) {
      reasons.add(
        '最初の施設として配置しました。'
        '入園後の施設までの移動'
        '${EntryPredictionService.gateToFirstFacilityMinutes}分は'
        '入園予測に含めています。',
      );
    } else if (previousAreaId == currentAreaId) {
      reasons.add(
        '直前の施設と同じエリアのため、'
        '移動を少なくしました。',
      );
    } else {
      reasons.add('希望時間とエリア順を考慮して配置しました。');
    }

    if (facility.isRestaurant) {
      reasons.add(
        'レストラン種別'
        '「${facility.restaurantType.label}」を'
        '考慮しました。',
      );
    }

    if (facility.isShop) {
      reasons.add(
        'ショップ種別'
        '「${facility.shopType.label}」を'
        '考慮しました。',
      );
    }

    if (facility.isCapsuleToy && preference?.prioritizeCapsuleToy == true) {
      reasons.add(
        'カプセルトイを優先する設定のため、'
        '早い時間帯を優先しました。',
      );
    }

    if (_usesUnlimitedRideBenefit(
      facility: facility,
      settings: settings,
      unlimitedRideBufferMinutes: unlimitedRideBufferMinutes,
    )) {
      reasons.add(
        'バケーションパッケージのアトラクション利用券スペシャル（乗り放題）対象として、'
        'プライオリティ・アクセス・エントランス利用を前提に配置しました。'
        '公式は具体的な待ち時間を保証していないため、施設ごとの館内導線・プレショー・搭乗前工程を考慮した'
        'Disney Planner計画用バッファを使用しています。',
      );
    } else if (preference != null) {
      reasons.add(
        _accessMethodReason(facility: facility, preference: preference),
      );

      if (preference.accessMethod == FacilityAccessMethod.entryRequest) {
        reasons.add(_lotteryFallbackReason(preference.lotteryFallbackAction));
      }
    }

    final greetingPlan = greetingWaitPlanning[facility.id];
    if (facility.category == FacilityCategory.greeting && greetingPlan != null) {
      if (greetingPlan.isCharacterBirthday) {
        reasons.add(
          '${greetingPlan.birthdayCharacterNames.join('・')}の記念日のため特殊混雑日として扱い、'
          'Disney Planner計画待ち${greetingPlan.birthdayPlanningWaitMinutes}分を確保しました。'
          '${greetingPlan.birthdayExtremeRiskMinutes}分級は極端混雑リスクとして別管理し、'
          '通常の予測待ち時間とは扱っていません。',
        );
      } else if (greetingPlan.parkCrowdMultiplier > 1.001) {
        reasons.add(
          'Git収集済みのパーク混雑傾向からグリーティング基準待ち時間を'
          '${greetingPlan.parkCrowdMultiplier.toStringAsFixed(2)}倍で安全側補正しています。'
          'この値はグリーティング自体の実測待ち時間ではありません。',
        );
      }
    }

    if (facility.supportsMobileOrder) {
      reasons.add('モバイルオーダー対応施設です。');
    }

    if (facility.supportsPrioritySeating) {
      reasons.add('プライオリティ・シーティング対応施設です。');
    }

    final closingReason = _buildClosingUrgencyReason(
      facility: facility,
      scheduledStartMinutes: scheduledStartMinutes,
      durationMinutes: durationMinutes,
    );
    if (closingReason != null) {
      reasons.add(closingReason);
    }

    if (waitTimingReason != null && waitTimingReason.trim().isNotEmpty) {
      reasons.add(waitTimingReason);
    }

    final waitReason = _buildWaitReason(waitDecision);

    if (waitReason != null) {
      reasons.add(waitReason);
    }

    if (preference == null) {
      reasons.add('施設の基本優先度を使用しています。');
    } else {
      if (_usesQueueWaitPlanning(facility) &&
          _hasReliableWaitProfile(
            facilityId: facility.id,
            waitProfiles: waitProfiles,
          )) {
        reasons.add(
          '希望時間「${preference.preferredTime.label}」と、'
          '収集した待ち時間実績・移動・体験時間による総時間評価を考慮しました。',
        );
      } else if (_usesQueueWaitPlanning(facility)) {
        reasons.add(
          facility.category == FacilityCategory.greeting
              ? '希望時間「${preference.preferredTime.label}」を考慮しました。'
                  'グリーティング待ち時間の実測データが取得できないため、'
                  '計画用暫定値を使用しています。暫定値は実測値としては扱っていません。'
              : '希望時間「${preference.preferredTime.label}」を考慮しました。'
                  '待ち時間実績が不足しているため、フォールバック値を実績値としては扱っていません。',
        );
      } else {
        reasons.add(
          '優先度'
          '「${preference.priority.label}」、'
          '希望時間'
          '「${preference.preferredTime.label}」を'
          '考慮しました。',
        );
      }
    }

    reasons.add('所要時間を$durationMinutes分として配置しました。');

    return reasons.where((reason) => reason.isNotEmpty).join(' ');
  }

  String? _buildClosingUrgencyReason({
    required Facility facility,
    required int scheduledStartMinutes,
    required int durationMinutes,
  }) {
    final hours = facility.operatingHours;
    if (hours == null) return null;

    final closeMinutes = _toMinutes(hours.close.hour, hours.close.minute);
    final minutesUntilClose = closeMinutes - scheduledStartMinutes;
    if (minutesUntilClose < durationMinutes || minutesUntilClose > 120) {
      return null;
    }

    return '営業終了まで約$minutesUntilClose分のため、後回しにすると利用機会を失う可能性を考慮しました。';
  }

  String _accessMethodReason({
    required Facility facility,
    required PlanPreference preference,
  }) {
    return switch (preference.accessMethod) {
      FacilityAccessMethod.standby => '通常待機・通常利用で予定を作成しました。',
      FacilityAccessMethod.dpa =>
        facility.supportsDpa
            ? 'ディズニー・プレミアアクセスを利用する設定です。'
            : 'DPA指定ですが、この施設はDPA対象外として登録されています。',
      FacilityAccessMethod.priorityPass =>
        facility.supportsPriorityPass
            ? 'プライオリティパスを利用する設定です。'
            : 'プライオリティパス指定ですが、対象外として登録されています。',
      FacilityAccessMethod.standbyPass =>
        facility.supportsStandbyPass
            ? 'スタンバイパスが発行されている場合に利用する設定です。'
            : 'スタンバイパス指定ですが、対象外として登録されています。',
      FacilityAccessMethod.entryRequest =>
        facility.requiresEntryRequest
            ? 'エントリー受付へ申し込む前提です。'
            : 'エントリー受付指定ですが、対象外として登録されています。',
      FacilityAccessMethod.reservation =>
        preference.hasReservationTime
            ? '予約時刻を優先する設定です。'
            : '予約利用の設定ですが、予約時刻は未入力です。',
      FacilityAccessMethod.freeSeating => '自由席・自由鑑賞を利用する設定です。',
    };
  }

  String _lotteryFallbackReason(LotteryFallbackAction action) {
    return switch (action) {
      LotteryFallbackAction.alternativeFacility =>
        'エントリー受付に外れた場合は、'
            '別の施設へ行く設定です。',
      LotteryFallbackAction.freeSeating =>
        'エントリー受付に外れた場合は、'
            '自由席・自由鑑賞を利用する設定です。',
      LotteryFallbackAction.retryLater =>
        'エントリー受付に外れた場合は、'
            '後で再検討する設定です。',
      LotteryFallbackAction.dpaIfAvailable =>
        'エントリー受付に外れた場合は、DPA対象かつ販売中なら購入候補として再検討します。'
            'アトラクションDPAの上限とは別扱いです。',
      LotteryFallbackAction.skip =>
        'エントリー受付に外れた場合は、'
            'この施設を諦める設定です。',
    };
  }

  String? _buildWaitReason(_WaitToleranceDecision decision) {
    final waitMinutes = decision.waitMinutes;

    if (waitMinutes == null) {
      return null;
    }

    final effectiveWaitMinutes = decision.effectiveWaitMinutes ?? waitMinutes;

    if (effectiveWaitMinutes != waitMinutes) {
      return '通常の予想待ち時間は'
          '$waitMinutes分ですが、'
          '選択した利用方法を考慮し、'
          '待ち時間制限の対象外として扱いました。';
    }

    if (decision.exceededButKept) {
      return decision.reason;
    }

    final maxMinutes = decision.maxMinutes;

    if (maxMinutes == null) {
      return '予想待ち時間は'
          '$waitMinutes分です。'
          '待ち時間は気にしない設定です。';
    }

    return '予想待ち時間は'
        '$waitMinutes分で、'
        '許容時間の'
        '$maxMinutes分以内です。';
  }

  String? _buildScheduleNote({
    required Facility facility,
    required PlanPreference? preference,
  }) {
    final notes = <String>[];

    final description = facility.description?.trim();

    if (description != null && description.isNotEmpty) {
      notes.add(description);
    }

    final memo = preference?.memo.trim();

    if (memo != null && memo.isNotEmpty) {
      notes.add('ユーザーメモ：$memo');
    }

    if (preference != null &&
        preference.accessMethod == FacilityAccessMethod.entryRequest) {
      notes.add('エントリー受付の当落は当日に確認してください。');
    }

    if (notes.isEmpty) {
      return null;
    }

    return notes.join('\n');
  }

  bool _isShowOrParade(Facility facility) {
    return facility.category == FacilityCategory.show ||
        facility.category == FacilityCategory.parade;
  }

  int? _parseTimeText(String value) {
    final normalized = value.trim().replaceAll('：', ':');

    if (normalized.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'^([01]?\d|2[0-3]):([0-5]\d)$',
    ).firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final hour = int.tryParse(match.group(1) ?? '');

    final minute = int.tryParse(match.group(2) ?? '');

    if (hour == null || minute == null) {
      return null;
    }

    return _toMinutes(hour, minute);
  }

  ScheduleItem _createScheduleItem({
    required String id,
    required String title,
    required ScheduleItemType type,
    required int startMinutes,
    required int endMinutes,
    String? facilityId,
    String? reason,
    String? note,
    int? estimatedWaitMinutes,
    int? experienceMinutes,
    String? waitEstimateSource,
    FacilityAccessMethod? accessMethod,
    bool usesVacationPackageUnlimited = false,
    int? standbyWaitMinutes,
    int? priorityAccessBufferMinutes,
  }) {
    return ScheduleItem(
      id: id,
      title: title,
      type: type,
      startHour: startMinutes ~/ 60,
      startMinute: startMinutes % 60,
      endHour: endMinutes ~/ 60,
      endMinute: endMinutes % 60,
      facilityId: facilityId,
      reason: reason,
      note: note,
      estimatedWaitMinutes: estimatedWaitMinutes,
      experienceMinutes: experienceMinutes,
      waitEstimateSource: waitEstimateSource,
      accessMethod: accessMethod,
      usesVacationPackageUnlimited: usesVacationPackageUnlimited,
      standbyWaitMinutes: standbyWaitMinutes,
      priorityAccessBufferMinutes: priorityAccessBufferMinutes,
    );
  }

  bool _timesOverlap(
    int firstStart,
    int firstEnd,
    int secondStart,
    int secondEnd,
  ) {
    if (firstStart == firstEnd || secondStart == secondEnd) {
      return false;
    }

    return firstStart < secondEnd && secondStart < firstEnd;
  }

  int _itemStartMinutes(ScheduleItem item) {
    return _toMinutes(item.startHour, item.startMinute);
  }

  int _itemEndMinutes(ScheduleItem item) {
    return _toMinutes(item.endHour, item.endMinute);
  }

  String _formatMinutes(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _toMinutes(int hour, int minute) {
    return hour * 60 + minute;
  }

  int _maximum(int first, int second) {
    return first >= second ? first : second;
  }

  int _minimum(int first, int second) {
    return first <= second ? first : second;
  }
}

class _UnifiedDaySearchState {
  const _UnifiedDaySearchState({
    required this.items,
    required this.remaining,
    this.standbyWaitMinutes = 0,
    this.movementMinutes = 0,
    this.fragmentedFreeMinutes = 0,
    this.compactFragmentationMinutes = 0,
  });

  final List<ScheduleItem> items;
  final Set<String> remaining;
  final int standbyWaitMinutes;
  final int movementMinutes;
  final int fragmentedFreeMinutes;
  final int compactFragmentationMinutes;
}

class _FixedPerformanceCandidate {
  const _FixedPerformanceCandidate({
    required this.facility,
    required this.preference,
  });

  final Facility facility;
  final PlanPreference? preference;
}

class _FixedAccessCandidate {
  const _FixedAccessCandidate({
    required this.facility,
    required this.preference,
  });

  final Facility facility;
  final PlanPreference? preference;
}

class _WaitEstimate {
  const _WaitEstimate({
    required this.waitMinutes,
    required this.source,
    this.isPriorityAccessBuffer = false,
  });

  final int waitMinutes;
  final String source;
  final bool isPriorityAccessBuffer;
}


class _OpeningSequenceDecision {
  const _OpeningSequenceDecision({
    required this.facility,
    required this.reason,
    required this.sequenceFacilityIds,
  });

  final Facility facility;
  final String reason;
  final List<String> sequenceFacilityIds;
}

class _OpeningSequence {
  const _OpeningSequence({
    required this.facilities,
    required this.score,
    required this.firstStep,
  });

  final List<Facility> facilities;
  final double score;
  final _OpeningStepEvaluation firstStep;
}

class _OpeningStepEvaluation {
  const _OpeningStepEvaluation({
    required this.score,
    required this.waitMinutes,
    required this.movementMinutes,
    required this.deferLossMinutes,
    required this.alternativeAccessPenalty,
    required this.dayDifficultyMinutes,
    required this.transportPenalty,
    required this.expertScore,
    required this.expertReason,
  });

  const _OpeningStepEvaluation.empty()
      : score = 0,
        waitMinutes = 0,
        movementMinutes = 0,
        deferLossMinutes = 0,
        alternativeAccessPenalty = 0,
        dayDifficultyMinutes = 0,
        transportPenalty = 0,
        expertScore = 0,
        expertReason = '';

  final double score;
  final int waitMinutes;
  final int movementMinutes;
  final int deferLossMinutes;
  final double alternativeAccessPenalty;
  final int dayDifficultyMinutes;
  final double transportPenalty;
  final double expertScore;
  final String expertReason;
}

class _FutureAnchorImpact {
  const _FutureAnchorImpact({
    required this.movementMinutes,
    required this.fitsBeforeAnchor,
  });

  const _FutureAnchorImpact.none()
      : movementMinutes = 0,
        fitsBeforeAnchor = true;

  final int movementMinutes;
  final bool fitsBeforeAnchor;
}

class _NextFacilityDecision {
  const _NextFacilityDecision({
    required this.facility,
    this.reason,
    this.isOpeningStrategy = false,
    this.openingSequenceFacilityIds = const [],
  });

  final Facility facility;
  final String? reason;
  final bool isOpeningStrategy;
  final List<String> openingSequenceFacilityIds;
}

class _WaitAwareCandidate {
  const _WaitAwareCandidate({
    required this.facility,
    required this.score,
    required this.timing,
    required this.expertScore,
    required this.expertReason,
    required this.waitSpreadMinutes,
    required this.cheapWindowCaptureMinutes,
    required this.conditionalWaitSatisfied,
  });

  final Facility facility;
  final double score;
  final _WaitTimingOpportunity? timing;
  final double expertScore;
  final String expertReason;
  final int waitSpreadMinutes;
  final int cheapWindowCaptureMinutes;
  final bool conditionalWaitSatisfied;
}

class _WaitTimingOpportunity {
  const _WaitTimingOpportunity({
    required this.currentBand,
    required this.currentWaitMinutes,
    required this.bestFutureBand,
    required this.bestFutureWaitMinutes,
    required this.delayPenaltyMinutes,
  });

  final WaitTimeBand currentBand;
  final int currentWaitMinutes;
  final WaitTimeBand bestFutureBand;
  final int bestFutureWaitMinutes;

  /// Positive means "doing it later is worse"; negative means later is better.
  final int delayPenaltyMinutes;
}

class _WaitToleranceDecision {
  const _WaitToleranceDecision({
    required this.shouldSkip,
    this.waitMinutes,
    this.effectiveWaitMinutes,
    this.maxMinutes,
    this.exceededMinutes = 0,
    this.exceededButKept = false,
    this.reason,
  });

  final bool shouldSkip;

  final int? waitMinutes;
  final int? effectiveWaitMinutes;
  final int? maxMinutes;

  final int exceededMinutes;
  final bool exceededButKept;

  final String? reason;
}


class _CoveredWishTimingCost {
  const _CoveredWishTimingCost({
    required this.standbyWaitMinutes,
    required this.movementMinutes,
    this.fragmentedFreeMinutes = 0,
    this.compactFragmentationMinutes = 0,
  });

  final int standbyWaitMinutes;
  final int movementMinutes;
  final int fragmentedFreeMinutes;
  final int compactFragmentationMinutes;
}

class _NearestWaitRange {
  const _NearestWaitRange({required this.band, required this.range});

  final WaitTimeBand band;
  final WaitTimeRange range;
}
