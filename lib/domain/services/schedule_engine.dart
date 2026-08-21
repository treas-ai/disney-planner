import '../entities/day_schedule.dart';
import '../entities/event_impact.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
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
import '../enums/schedule_item_type.dart';
import '../enums/wait_time_band.dart';
import 'event_impact_engine.dart';
import 'meal_planner.dart';
import 'route_optimizer.dart';
import 'time_allocator.dart';

class ScheduleEngine {
  const ScheduleEngine({
    this.timeAllocator = const TimeAllocator(),
    this.mealPlanner = const MealPlanner(),
    this.routeOptimizer = const RouteOptimizer(),
    this.eventImpactEngine = const EventImpactEngine(),
  });

  final TimeAllocator timeAllocator;
  final MealPlanner mealPlanner;
  final RouteOptimizer routeOptimizer;
  final EventImpactEngine eventImpactEngine;

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
  }) {
    final items = <ScheduleItem>[];
    final visitDate = settings.visitDate ?? DateTime.now();

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
      facilities: operationalFacilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      targetDate: visitDate,
    );

    final fixedAccessFacilityIds = _addFixedAccessFacilities(
      items: items,
      facilities: operationalFacilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
      targetDate: visitDate,
    );

    final mealPlan = mealPlanner.plan(
      settings: settings,
      facilities: operationalFacilities,
      preferences: preferences,
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

    final regularFacilities = operationalFacilities
        .where((facility) {
          final isAssignedRestaurant =
              facility.category == FacilityCategory.restaurant &&
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

          return !isAssignedRestaurant &&
              !isFixedPerformance &&
              !isFixedAccess &&
              !(preference?.isExcluded ?? false);
        })
        .toList(growable: false);

    final optimizedFacilities = _prioritizeMorningAttractions(
      routeOptimizer.optimize(
        facilities: regularFacilities,
        preferences: preferences,
      ),
      preferences: preferences,
      morningScores: morningScores,
    );

    var currentMinutes = entryEndMinutes;
    String? previousAreaId;

    for (final facility in optimizedFacilities) {
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

      final movementMinutes = _calculateMovementMinutes(
        previousAreaId: previousAreaId,
        currentAreaId: facility.areaId,
        atMinutes: currentMinutes,
        eventImpacts: eventImpacts,
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
      );
      final durationMinutes = _resolvePlannedFacilityDuration(
        facility: facility,
        preference: preference,
        waitEstimate: waitEstimate,
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

      final finalStartMinutes = _findAvailableStart(
        requestedStartMinutes: adjustedStartMinutes,
        durationMinutes: durationMinutes,
        items: items,
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

      final endMinutes = finalStartMinutes + durationMinutes;

      items.add(
        _createScheduleItem(
          id: 'schedule_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: finalStartMinutes,
          endMinutes: endMinutes,
          facilityId: facility.id,
          reason: _buildReason(
            facility: facility,
            preference: preference,
            previousAreaId: previousAreaId,
            currentAreaId: facility.areaId,
            durationMinutes: durationMinutes,
            scheduledStartMinutes: finalStartMinutes,
            waitDecision: waitDecision,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
          estimatedWaitMinutes: facility.category == FacilityCategory.attraction
              ? waitEstimate.waitMinutes
              : null,
          experienceMinutes: facility.category == FacilityCategory.attraction
              ? _resolveFacilityDuration(facility)
              : null,
          waitEstimateSource: facility.category == FacilityCategory.attraction
              ? waitEstimate.source
              : null,
        ),
      );

      currentMinutes = endMinutes;
      previousAreaId = facility.areaId;
    }

    final latestScheduledEnd = items.fold<int>(
      exitMinutes,
      (latest, item) => _maximum(latest, _itemEndMinutes(item)),
    );

    items.add(
      _createScheduleItem(
        id: 'exit',
        title: '退園',
        type: ScheduleItemType.exit,
        startMinutes: latestScheduledEnd,
        endMinutes: latestScheduledEnd,
        reason: latestScheduledEnd > exitMinutes
            ? '公式公演の終了時刻を優先し、退園時刻を後ろへ調整しました。'
            : '設定された退園時間です。',
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
          return candidate.preference?.fixedTimeStatus ==
                  FixedTimeStatus.confirmed &&
              candidate.preference?.hasPreferredPerformanceTime == true;
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
              preference.fixedTimeStatus != FixedTimeStatus.confirmed ||
              !preference.hasScheduledAccessTime ||
              _isShowOrParade(candidate.facility) ||
              candidate.facility.isRestaurant) {
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

      final durationMinutes = _resolveFacilityDuration(facility);
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
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
        ),
      );

      addedFacilityIds.add(facility.id);
    }

    return addedFacilityIds;
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
        requestedStartMinutes: _toMinutes(12, 0),
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
        requestedStartMinutes: _toMinutes(18, 0),
        entryMinutes: entryMinutes,
        exitMinutes: exitMinutes,
        reason:
            '夕食ありの設定ですが、'
            '選択済みの夕食レストランがないため'
            '通常の夕食予定を追加しました。',
      );
    }
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

    final requestedStartMinutes = hasReservation
        ? reservationMinutes
        : _maximum(assignment.startMinutes, entryMinutes);

    final durationMinutes = _resolveFacilityDuration(facility);

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
  }) {
    if (previousAreaId == null) {
      return 0;
    }

    final baseMinutes = previousAreaId == currentAreaId
        ? _sameAreaMovementMinutes
        : _movementDurationMinutes;

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


  List<Facility> _prioritizeMorningAttractions(
    List<Facility> facilities, {
    required List<PlanPreference> preferences,
    Map<String, double> morningScores = const {},
  }) {
    if (facilities.length <= 1) {
      return facilities;
    }

    // 入園直後は、営業時間待ちの飲食施設を先頭に置かず、
    // 実際に利用できるアトラクションを優先する。
    // 先頭2枠だけを朝一枠として扱い、それ以降は既存の
    // RouteOptimizer の順序を維持して影響範囲を限定する。
    final morningAttractions = facilities.where((facility) {
      if (facility.category != FacilityCategory.attraction) {
        return false;
      }
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );
      return preference?.fixedTimeStatus != FixedTimeStatus.confirmed;
    }).toList(growable: false)
      ..sort((a, b) {
        final aScore = morningScores[a.id];
        final bScore = morningScores[b.id];
        if (aScore != null || bScore != null) {
          final scoreCompare = (bScore ?? double.negativeInfinity)
              .compareTo(aScore ?? double.negativeInfinity);
          if (scoreCompare != 0) return scoreCompare;
        }
        final aPref = _findPreference(facilityId: a.id, preferences: preferences);
        final bPref = _findPreference(facilityId: b.id, preferences: preferences);
        final priorityCompare = (bPref?.priority.value ?? b.priority.value)
            .compareTo(aPref?.priority.value ?? a.priority.value);
        if (priorityCompare != 0) return priorityCompare;
        return a.displayOrder.compareTo(b.displayOrder);
      });

    final topMorningAttractions = morningAttractions.take(2).toList(growable: false);

    if (topMorningAttractions.isEmpty) {
      return facilities;
    }

    final morningIds = topMorningAttractions.map((facility) => facility.id).toSet();
    return <Facility>[
      ...topMorningAttractions,
      ...facilities.where((facility) => !morningIds.contains(facility.id)),
    ];
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

  int _resolvePlannedFacilityDuration({
    required Facility facility,
    required PlanPreference? preference,
    _WaitEstimate? waitEstimate,
  }) {
    final experienceMinutes = _resolveFacilityDuration(facility);

    if (facility.category != FacilityCategory.attraction) {
      return experienceMinutes;
    }

    final method = preference?.accessMethod ?? FacilityAccessMethod.standby;
    final usesShortenedQueue =
        (method == FacilityAccessMethod.dpa && facility.supportsDpa) ||
        (method == FacilityAccessMethod.priorityPass &&
            facility.supportsPriorityPass) ||
        (method == FacilityAccessMethod.standbyPass &&
            facility.supportsStandbyPass) ||
        (preference?.useDpa == true && facility.supportsDpa) ||
        (preference?.usePriorityPass == true &&
            facility.supportsPriorityPass) ||
        (preference?.useStandbyPass == true && facility.supportsStandbyPass);

    // DPA/PP等でも入場から乗車までの時間は0分ではないため、
    // 最低限のキュー・乗降バッファを確保する。
    if (usesShortenedQueue) {
      return experienceMinutes + 10;
    }

    return experienceMinutes +
        (waitEstimate?.waitMinutes ?? _fallbackWaitMinutes(facility));
  }

  _WaitEstimate _resolveWaitEstimate({
    required Facility facility,
    required PlanPreference? preference,
    required List<TimeBandWaitProfile> waitProfiles,
    required int scheduledStartMinutes,
  }) {
    final method = preference?.accessMethod ?? FacilityAccessMethod.standby;
    final shortened =
        (method == FacilityAccessMethod.dpa && facility.supportsDpa) ||
        (method == FacilityAccessMethod.priorityPass && facility.supportsPriorityPass) ||
        (method == FacilityAccessMethod.standbyPass && facility.supportsStandbyPass) ||
        (preference?.useDpa == true && facility.supportsDpa) ||
        (preference?.usePriorityPass == true && facility.supportsPriorityPass) ||
        (preference?.useStandbyPass == true && facility.supportsStandbyPass);

    if (shortened) {
      return const _WaitEstimate(
        waitMinutes: 10,
        source: 'パス利用時の暫定バッファ',
      );
    }

    if (facility.waitTime != null) {
      return _WaitEstimate(
        waitMinutes: facility.waitTime!.minutes,
        source: '施設の待ち時間データ',
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
      if (range != null && range.typicalMinutes > 0) {
        return _WaitEstimate(
          waitMinutes: range.typicalMinutes,
          source:
              '実績待ち時間プロファイル（${band.label}、${profile.source}、サンプル${profile.sampleCount}件）',
        );
      }

      // 対象帯だけ観測が無い場合は、同じ施設の最も近い時間帯の
      // 実績を参照する。施設全体に有効実績が無い場合は補完せず、
      // 従来の安全側フォールバックへ戻す。
      final nearest = _nearestValidWaitRange(profile: profile, targetBand: band);
      if (nearest != null) {
        return _WaitEstimate(
          waitMinutes: nearest.range.typicalMinutes,
          source:
              '実績待ち時間プロファイル（${band.label}を${nearest.band.label}から近接参照、${profile.source}、サンプル${profile.sampleCount}件）',
        );
      }
    }

    return _WaitEstimate(
      waitMinutes: _fallbackWaitMinutes(facility),
      source: '待ち時間データ未登録のため優先度別の安全側暫定値',
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
  }) {
    final reasons = <String>[
      '${_accessMethodShortLabel(preference.accessMethod)}の利用時刻'
          '「${preference.scheduledAccessTime}」へ固定配置しました。',
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
    final reasons = <String>[
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

  String _buildReason({
    required Facility facility,
    required PlanPreference? preference,
    required String? previousAreaId,
    required String currentAreaId,
    required int durationMinutes,
    required int scheduledStartMinutes,
    required _WaitToleranceDecision waitDecision,
  }) {
    final reasons = <String>[];

    if (previousAreaId == null) {
      reasons.add('最初の施設として配置しました。');
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

    if (preference != null) {
      reasons.add(
        _accessMethodReason(facility: facility, preference: preference),
      );

      if (preference.accessMethod == FacilityAccessMethod.entryRequest) {
        reasons.add(_lotteryFallbackReason(preference.lotteryFallbackAction));
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

    final waitReason = _buildWaitReason(waitDecision);

    if (waitReason != null) {
      reasons.add(waitReason);
    }

    if (preference == null) {
      reasons.add('施設の基本優先度を使用しています。');
    } else {
      reasons.add(
        '優先度'
        '「${preference.priority.label}」、'
        '希望時間'
        '「${preference.preferredTime.label}」、'
        '待ち時間許容'
        '「${preference.waitTolerance.label}」を'
        '考慮しました。',
      );
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
  const _WaitEstimate({required this.waitMinutes, required this.source});

  final int waitMinutes;
  final String source;
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


class _NearestWaitRange {
  const _NearestWaitRange({required this.band, required this.range});

  final WaitTimeBand band;
  final WaitTimeRange range;
}
