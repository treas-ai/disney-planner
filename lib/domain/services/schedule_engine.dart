import '../entities/day_schedule.dart';
import '../entities/event_impact.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/trip_settings.dart';
import '../enums/facility_access_method.dart';
import '../enums/facility_category.dart';
import '../enums/fixed_time_status.dart';
import '../enums/lottery_fallback_action.dart';
import '../enums/preferred_time.dart';
import '../enums/schedule_item_type.dart';
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

  static const int _entryDurationMinutes = 15;
  static const int _movementDurationMinutes = 15;
  static const int _sameAreaMovementMinutes = 5;
  static const int _fallbackMealDurationMinutes = 60;

  DaySchedule generate({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
    List<EventImpact> eventImpacts = const [],
  }) {
    final items = <ScheduleItem>[];

    final entryMinutes = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );

    final exitMinutes = _toMinutes(
      settings.exitTimeHour,
      settings.exitTimeMinute,
    );

    final entryEndMinutes = _minimum(
      entryMinutes + _entryDurationMinutes,
      exitMinutes,
    );

    items.add(
      _createScheduleItem(
        id: 'entry',
        title: '入園',
        type: ScheduleItemType.entry,
        startMinutes: entryMinutes,
        endMinutes: entryEndMinutes,
        reason: '設定された入園時間です。',
      ),
    );

    final fixedRestaurantFacilityIds = _addConfirmedRestaurantReservations(
      items: items,
      facilities: facilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
    );

    final fixedPerformanceFacilityIds = _addFixedPerformanceFacilities(
      items: items,
      facilities: facilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
    );

    final fixedAccessFacilityIds = _addFixedAccessFacilities(
      items: items,
      facilities: facilities,
      preferences: preferences,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
    );

    final mealPlan = mealPlanner.plan(
      settings: settings,
      facilities: facilities,
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
      );
    }

    _addFallbackMeals(
      items: items,
      settings: settings,
      mealPlan: mealPlan,
      entryMinutes: entryEndMinutes,
      exitMinutes: exitMinutes,
    );

    final regularFacilities = facilities
        .where((facility) {
          final isAssignedRestaurant =
              facility.category == FacilityCategory.restaurant &&
              (mealPlan.assignedFacilityIds.contains(facility.id) ||
                  fixedRestaurantFacilityIds.contains(facility.id));

          final isFixedPerformance = fixedPerformanceFacilityIds.contains(
            facility.id,
          );

          final isFixedAccess = fixedAccessFacilityIds.contains(facility.id);

          return !isAssignedRestaurant && !isFixedPerformance && !isFixedAccess;
        })
        .toList(growable: false);

    final optimizedFacilities = routeOptimizer.optimize(
      facilities: regularFacilities,
      preferences: preferences,
    );

    var currentMinutes = entryEndMinutes;
    String? previousAreaId;

    for (final facility in optimizedFacilities) {
      if (!facility.isOpen) {
        continue;
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

      final durationMinutes = _resolveFacilityDuration(facility);

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
            waitDecision: waitDecision,
          ),
          note: _buildScheduleNote(facility: facility, preference: preference),
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
  }) {
    final added = <String>{};
    final candidates =
        facilities
            .where((facility) {
              if (!facility.isOpen || !facility.isRestaurant) {
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
  }) {
    final addedFacilityIds = <String>{};

    final candidates = facilities
        .where((facility) {
          return facility.isOpen && _isShowOrParade(facility);
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

          if (!candidate.facility.isOpen ||
              preference == null ||
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
  }) {
    final facility = assignment.facility;

    if (!facility.isOpen) {
      return;
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

  int? _adjustStartForOperatingHours({
    required Facility facility,
    required int requestedStartMinutes,
    required int durationMinutes,
    required int exitMinutes,
  }) {
    final operatingHours = facility.operatingHours;

    if (operatingHours == null) {
      if (requestedStartMinutes + durationMinutes > exitMinutes) {
        return null;
      }

      return requestedStartMinutes;
    }

    final openMinutes = _toMinutes(
      operatingHours.open.hour,
      operatingHours.open.minute,
    );

    final closeMinutes = _toMinutes(
      operatingHours.close.hour,
      operatingHours.close.minute,
    );

    final adjustedStart = _maximum(requestedStartMinutes, openMinutes);

    if (adjustedStart + durationMinutes > closeMinutes) {
      return null;
    }

    if (adjustedStart + durationMinutes > exitMinutes) {
      return null;
    }

    return adjustedStart;
  }

  bool _fitsOperatingHours({
    required Facility facility,
    required int startMinutes,
    required int durationMinutes,
  }) {
    final operatingHours = facility.operatingHours;

    if (operatingHours == null) {
      return true;
    }

    final openMinutes = _toMinutes(
      operatingHours.open.hour,
      operatingHours.open.minute,
    );

    final closeMinutes = _toMinutes(
      operatingHours.close.hour,
      operatingHours.close.minute,
    );

    final endMinutes = startMinutes + durationMinutes;

    return startMinutes >= openMinutes && endMinutes <= closeMinutes;
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

        if (_timesOverlap(
          candidateStart,
          candidateStart + durationMinutes,
          itemStart,
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
