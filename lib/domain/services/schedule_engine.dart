import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/trip_settings.dart';
import '../enums/facility_category.dart';
import '../enums/preferred_time.dart';
import '../enums/schedule_item_type.dart';
import 'meal_planner.dart';
import 'route_optimizer.dart';
import 'time_allocator.dart';

class ScheduleEngine {
  const ScheduleEngine({
    this.timeAllocator = const TimeAllocator(),
    this.mealPlanner = const MealPlanner(),
    this.routeOptimizer = const RouteOptimizer(),
  });

  final TimeAllocator timeAllocator;
  final MealPlanner mealPlanner;
  final RouteOptimizer routeOptimizer;

  static const int _entryDurationMinutes = 15;
  static const int _movementDurationMinutes = 15;
  static const int _sameAreaMovementMinutes = 5;
  static const int _fallbackMealDurationMinutes = 60;

  DaySchedule generate({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
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

    final mealPlan = mealPlanner.plan(
      settings: settings,
      facilities: facilities,
      preferences: preferences,
    );

    for (final assignment in mealPlan.assignments) {
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
        .where(
          (facility) =>
              facility.category != FacilityCategory.restaurant ||
              !mealPlan.assignedFacilityIds.contains(facility.id),
        )
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
          note: facility.description,
        ),
      );

      currentMinutes = endMinutes;
      previousAreaId = facility.areaId;
    }

    items.add(
      _createScheduleItem(
        id: 'exit',
        title: '退園',
        type: ScheduleItemType.exit,
        startMinutes: exitMinutes,
        endMinutes: exitMinutes,
        reason: '設定された退園時間です。',
      ),
    );

    items.sort(
      (first, second) =>
          _itemStartMinutes(first).compareTo(_itemStartMinutes(second)),
    );

    return DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: settings.parkId,
      items: List<ScheduleItem>.unmodifiable(items),
      createdAt: DateTime.now(),
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
        reason: '朝食ありの設定ですが、選択済みの朝食レストランがないため通常の朝食予定を追加しました。',
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
        reason: '昼食ありの設定ですが、選択済みの昼食レストランがないため通常の昼食予定を追加しました。',
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
        reason: '夕食ありの設定ですが、選択済みの夕食レストランがないため通常の夕食予定を追加しました。',
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

    final requestedStartMinutes = _maximum(
      assignment.startMinutes,
      entryMinutes,
    );

    final durationMinutes = _resolveFacilityDuration(facility);

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

    final reason = _buildMealReason(
      assignment: assignment,
      durationMinutes: durationMinutes,
      waitDecision: waitDecision,
    );

    items.add(
      _createScheduleItem(
        id: '${assignment.slot.name}_${facility.id}',
        title: facility.name,
        type: _scheduleTypeForMealSlot(assignment.slot),
        startMinutes: startMinutes,
        endMinutes: startMinutes + durationMinutes,
        facilityId: facility.id,
        reason: reason,
        note: facility.description,
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
        reason: '許容時間を$exceededMinutes分超えますが、優先度が高いため候補に残しました。',
      );
    }

    return _WaitToleranceDecision(
      shouldSkip: true,
      waitMinutes: waitMinutes,
      effectiveWaitMinutes: effectiveWaitMinutes,
      maxMinutes: maxMinutes,
      exceededMinutes: exceededMinutes,
      reason: '予想待ち時間が許容時間を$exceededMinutes分超えるため、今回の予定から除外しました。',
    );
  }

  int _effectiveWaitMinutes({
    required Facility facility,
    required PlanPreference preference,
    required int originalWaitMinutes,
  }) {
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
  }) {
    if (previousAreaId == null) {
      return 0;
    }

    if (previousAreaId == currentAreaId) {
      return _sameAreaMovementMinutes;
    }

    return _movementDurationMinutes;
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

      for (final item in items) {
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

  String _buildMealReason({
    required MealAssignment assignment,
    required int durationMinutes,
    required _WaitToleranceDecision waitDecision,
  }) {
    final facility = assignment.facility;

    final reasons = <String>[assignment.reason];

    if (facility.isRestaurant) {
      reasons.add(
        'レストラン種別'
        '「${facility.restaurantType.label}」を'
        '考慮しました。',
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

    return reasons.join(' ');
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
      reasons.add('直前の施設と同じエリアのため、移動を少なくしました。');
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
      reasons.add('カプセルトイを優先する設定のため、早い時間帯を優先しました。');
    }

    if (preference?.useDpa == true && facility.supportsDpa) {
      reasons.add('ディズニー・プレミアアクセスを利用する設定です。');
    }

    if (preference?.usePriorityPass == true && facility.supportsPriorityPass) {
      reasons.add('プライオリティパスを利用する設定です。');
    }

    if (preference?.useStandbyPass == true && facility.supportsStandbyPass) {
      reasons.add('スタンバイパスが発行されている場合、利用する設定です。');
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

    return reasons.join(' ');
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
          'パス利用設定を考慮し、'
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
