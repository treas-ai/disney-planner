import '../entities/day_schedule.dart';
import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/schedule_item.dart';
import '../entities/trip_settings.dart';
import '../enums/facility_category.dart';
import '../enums/preferred_time.dart';
import '../enums/schedule_item_type.dart';
import 'meal_planner.dart';
import 'time_allocator.dart';

class ScheduleEngine {
  const ScheduleEngine({
    this.timeAllocator = const TimeAllocator(),
    this.mealPlanner = const MealPlanner(),
  });

  final TimeAllocator timeAllocator;
  final MealPlanner mealPlanner;

  static const int _entryDurationMinutes = 15;
  static const int _facilityDurationMinutes = 60;
  static const int _movementDurationMinutes = 15;
  static const int _mealDurationMinutes = 60;

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
        entryMinutes: entryEndMinutes,
        exitMinutes: exitMinutes,
      );
    }

    if (settings.wantsBreakfast &&
        _hasBreakfastTime(settings) &&
        mealPlan.assignmentFor(MealSlot.breakfast) == null) {
      _addFallbackMeal(
        items: items,
        id: 'breakfast',
        title: '朝食',
        type: ScheduleItemType.breakfast,
        requestedStartMinutes: entryEndMinutes,
        entryMinutes: entryEndMinutes,
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
        entryMinutes: entryEndMinutes,
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
        entryMinutes: entryEndMinutes,
        exitMinutes: exitMinutes,
        reason:
            '夕食ありの設定ですが、'
            '選択済みの夕食レストランがないため'
            '通常の夕食予定を追加しました。',
      );
    }

    final regularFacilities = facilities
        .where(
          (facility) =>
              facility.category != FacilityCategory.restaurant ||
              !mealPlan.assignedFacilityIds.contains(facility.id),
        )
        .toList();

    final sortedFacilities = _sortFacilitiesByPreference(
      facilities: regularFacilities,
      preferences: preferences,
    );

    var currentMinutes = entryEndMinutes;

    for (final facility in sortedFacilities) {
      final preference = _findPreference(
        facilityId: facility.id,
        preferences: preferences,
      );

      final preferredTime = preference?.preferredTime ?? PreferredTime.anytime;

      final allocation = timeAllocator.allocate(
        settings: settings,
        preferredTime: preferredTime,
      );

      final preferredStartMinutes = _toMinutes(
        allocation.startHour,
        allocation.startMinute,
      );

      final requestedStartMinutes = _maximum(
        currentMinutes,
        preferredStartMinutes,
      );

      final availableStartMinutes = _findAvailableStart(
        requestedStartMinutes: requestedStartMinutes,
        durationMinutes: _facilityDurationMinutes,
        items: items,
        exitMinutes: exitMinutes,
      );

      if (availableStartMinutes == null) {
        continue;
      }

      final endMinutes = availableStartMinutes + _facilityDurationMinutes;

      items.add(
        _createScheduleItem(
          id: 'schedule_${facility.id}',
          title: facility.name,
          type: ScheduleItemType.facility,
          startMinutes: availableStartMinutes,
          endMinutes: endMinutes,
          facilityId: facility.id,
          reason: _buildReason(preference),
          note: facility.description,
        ),
      );

      currentMinutes = _minimum(
        endMinutes + _movementDurationMinutes,
        exitMinutes,
      );
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
      items: List.unmodifiable(items),
      createdAt: DateTime.now(),
    );
  }

  void _addRestaurantMeal({
    required List<ScheduleItem> items,
    required MealAssignment assignment,
    required int entryMinutes,
    required int exitMinutes,
  }) {
    final requestedStartMinutes = _maximum(
      assignment.startMinutes,
      entryMinutes,
    );

    final startMinutes = _findAvailableStart(
      requestedStartMinutes: requestedStartMinutes,
      durationMinutes: _mealDurationMinutes,
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

    final endMinutes = startMinutes + _mealDurationMinutes;

    items.add(
      _createScheduleItem(
        id:
            '${assignment.slot.name}_'
            '${assignment.facility.id}',
        title: assignment.facility.name,
        type: _scheduleTypeForMealSlot(assignment.slot),
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        facilityId: assignment.facility.id,
        reason: assignment.reason,
        note: assignment.facility.description,
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
      durationMinutes: _mealDurationMinutes,
      items: items,
      exitMinutes: exitMinutes,
    );

    if (startMinutes == null) {
      return;
    }

    if (latestStartMinutes != null && startMinutes >= latestStartMinutes) {
      return;
    }

    final endMinutes = startMinutes + _mealDurationMinutes;

    items.add(
      _createScheduleItem(
        id: id,
        title: title,
        type: type,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        reason: reason,
      ),
    );
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

  List<Facility> _sortFacilitiesByPreference({
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    final sortedFacilities = List<Facility>.from(facilities);

    sortedFacilities.sort((first, second) {
      final firstPreference = _findPreference(
        facilityId: first.id,
        preferences: preferences,
      );

      final secondPreference = _findPreference(
        facilityId: second.id,
        preferences: preferences,
      );

      final timeComparison = _preferredTimeScore(
        firstPreference?.preferredTime,
      ).compareTo(_preferredTimeScore(secondPreference?.preferredTime));

      if (timeComparison != 0) {
        return timeComparison;
      }

      final firstPriority =
          firstPreference?.priority.value ?? first.priority.value;

      final secondPriority =
          secondPreference?.priority.value ?? second.priority.value;

      return secondPriority.compareTo(firstPriority);
    });

    return sortedFacilities;
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

  int _preferredTimeScore(PreferredTime? preferredTime) {
    return switch (preferredTime) {
      PreferredTime.morning => 0,
      PreferredTime.anytime || null => 1,
      PreferredTime.afternoon => 2,
      PreferredTime.evening => 3,
    };
  }

  ScheduleItemType _scheduleTypeForMealSlot(MealSlot slot) {
    return switch (slot) {
      MealSlot.breakfast => ScheduleItemType.breakfast,
      MealSlot.lunch => ScheduleItemType.lunch,
      MealSlot.dinner => ScheduleItemType.dinner,
    };
  }

  String _buildReason(PlanPreference? preference) {
    if (preference == null) {
      return '施設の基本優先度をもとに配置しました。';
    }

    return '優先度「${preference.priority.label}」、'
        '希望時間「${preference.preferredTime.label}」を'
        '考慮しました。';
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
