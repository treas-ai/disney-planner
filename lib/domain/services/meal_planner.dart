import '../entities/facility.dart';
import '../entities/plan_preference.dart';
import '../entities/trip_settings.dart';
import '../enums/facility_category.dart';
import '../enums/meal_preference.dart';
import '../enums/preferred_time.dart';

enum MealSlot { breakfast, lunch, dinner }

class MealAssignment {
  const MealAssignment({
    required this.slot,
    required this.facility,
    required this.startMinutes,
    required this.reason,
  });

  final MealSlot slot;
  final Facility facility;
  final int startMinutes;
  final String reason;
}

class MealPlan {
  const MealPlan({required this.assignments});

  final List<MealAssignment> assignments;

  MealAssignment? assignmentFor(MealSlot slot) {
    for (final assignment in assignments) {
      if (assignment.slot == slot) {
        return assignment;
      }
    }

    return null;
  }

  Set<String> get assignedFacilityIds {
    return assignments.map((assignment) => assignment.facility.id).toSet();
  }
}

class MealPlanner {
  const MealPlanner();

  MealPlan plan({
    required TripSettings settings,
    required List<Facility> facilities,
    required List<PlanPreference> preferences,
  }) {
    final restaurants = facilities
        .where((facility) => facility.category == FacilityCategory.restaurant)
        .toList();

    restaurants.sort(
      (first, second) => _priorityValue(
        second,
        preferences,
      ).compareTo(_priorityValue(first, preferences)),
    );

    final assignments = <MealSlot, MealAssignment>{};
    final flexibleRestaurants = <Facility>[];

    for (final restaurant in restaurants) {
      final preference = _findPreference(restaurant.id, preferences);

      final reservationTime = restaurant.reservation?.time;

      if (reservationTime != null) {
        final slot = _slotFromReservationTime(reservationTime, settings);

        if (slot != null &&
            _slotIsEnabled(slot: slot, settings: settings) &&
            !assignments.containsKey(slot)) {
          assignments[slot] = MealAssignment(
            slot: slot,
            facility: restaurant,
            startMinutes: _toMinutes(
              reservationTime.hour,
              reservationTime.minute,
            ),
            reason:
                '予約時間'
                '「${_timeLabel(reservationTime.hour, reservationTime.minute)}」'
                'から${_slotLabel(slot)}として配置しました。',
          );
        }

        continue;
      }

      final mealPreference =
          preference?.mealPreference ?? MealPreference.flexible;

      if (mealPreference == MealPreference.flexible) {
        flexibleRestaurants.add(restaurant);
        continue;
      }

      final slots = _slotsFromMealPreference(mealPreference);

      for (final slot in slots) {
        if (assignments.containsKey(slot)) {
          continue;
        }

        if (!_slotIsEnabled(slot: slot, settings: settings)) {
          continue;
        }

        assignments[slot] = MealAssignment(
          slot: slot,
          facility: restaurant,
          startMinutes: _defaultStartMinutes(slot, settings),
          reason:
              '食事利用「${mealPreference.label}」の設定から'
              '${_slotLabel(slot)}として配置しました。',
        );
      }
    }

    for (final restaurant in flexibleRestaurants) {
      final preference = _findPreference(restaurant.id, preferences);

      final slot = _selectFlexibleSlot(
        assignments: assignments,
        settings: settings,
        preferredTime: preference?.preferredTime ?? PreferredTime.anytime,
      );

      if (slot == null) {
        continue;
      }

      assignments[slot] = MealAssignment(
        slot: slot,
        facility: restaurant,
        startMinutes: _defaultStartMinutes(slot, settings),
        reason:
            '食事利用「空いている食事時間」の設定から、'
            '未使用の${_slotLabel(slot)}枠へ配置しました。',
      );
    }

    return MealPlan(
      assignments: List.unmodifiable(
        MealSlot.values
            .where(assignments.containsKey)
            .map((slot) => assignments[slot]!)
            .toList(),
      ),
    );
  }

  MealSlot? _slotFromReservationTime(
    DateTime reservationTime,
    TripSettings settings,
  ) {
    final reservationMinutes = _toMinutes(
      reservationTime.hour,
      reservationTime.minute,
    );

    final entryMinutes = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );

    final breakfastEnd = _toMinutes(10, 0);
    final dinnerStart = _toMinutes(16, 0);

    if (entryMinutes < breakfastEnd &&
        reservationMinutes >= entryMinutes &&
        reservationMinutes <= breakfastEnd) {
      return MealSlot.breakfast;
    }

    if (reservationMinutes > breakfastEnd && reservationMinutes < dinnerStart) {
      return MealSlot.lunch;
    }

    if (reservationMinutes >= dinnerStart) {
      return MealSlot.dinner;
    }

    return null;
  }

  List<MealSlot> _slotsFromMealPreference(MealPreference preference) {
    return [
      if (preference.includesBreakfast) MealSlot.breakfast,
      if (preference.includesLunch) MealSlot.lunch,
      if (preference.includesDinner) MealSlot.dinner,
    ];
  }

  MealSlot? _selectFlexibleSlot({
    required Map<MealSlot, MealAssignment> assignments,
    required TripSettings settings,
    required PreferredTime preferredTime,
  }) {
    final preferredSlot = switch (preferredTime) {
      PreferredTime.morning => MealSlot.breakfast,
      PreferredTime.afternoon => MealSlot.lunch,
      PreferredTime.evening => MealSlot.dinner,
      PreferredTime.anytime => null,
    };

    if (preferredSlot != null &&
        _slotIsAvailable(
          slot: preferredSlot,
          assignments: assignments,
          settings: settings,
        )) {
      return preferredSlot;
    }

    final fallbackOrder = [
      if (settings.wantsBreakfast && _hasBreakfastTime(settings))
        MealSlot.breakfast,
      if (settings.wantsLunch) MealSlot.lunch,
      if (settings.wantsDinner) MealSlot.dinner,
    ];

    for (final slot in fallbackOrder) {
      if (!assignments.containsKey(slot)) {
        return slot;
      }
    }

    return null;
  }

  bool _slotIsAvailable({
    required MealSlot slot,
    required Map<MealSlot, MealAssignment> assignments,
    required TripSettings settings,
  }) {
    return !assignments.containsKey(slot) &&
        _slotIsEnabled(slot: slot, settings: settings);
  }

  bool _slotIsEnabled({
    required MealSlot slot,
    required TripSettings settings,
  }) {
    return switch (slot) {
      MealSlot.breakfast =>
        settings.wantsBreakfast && _hasBreakfastTime(settings),
      MealSlot.lunch => settings.wantsLunch,
      MealSlot.dinner => settings.wantsDinner,
    };
  }

  bool _hasBreakfastTime(TripSettings settings) {
    final entryMinutes = _toMinutes(
      settings.entryTimeHour,
      settings.entryTimeMinute,
    );

    return entryMinutes < _toMinutes(10, 0);
  }

  int _defaultStartMinutes(MealSlot slot, TripSettings settings) {
    return switch (slot) {
      MealSlot.breakfast => _toMinutes(
        settings.entryTimeHour,
        settings.entryTimeMinute,
      ),
      MealSlot.lunch => _toMinutes(12, 0),
      MealSlot.dinner => _toMinutes(18, 0),
    };
  }

  int _priorityValue(Facility facility, List<PlanPreference> preferences) {
    final preference = _findPreference(facility.id, preferences);

    return preference?.priority.value ?? facility.priority.value;
  }

  PlanPreference? _findPreference(
    String facilityId,
    List<PlanPreference> preferences,
  ) {
    for (final preference in preferences) {
      if (preference.facilityId == facilityId) {
        return preference;
      }
    }

    return null;
  }

  String _slotLabel(MealSlot slot) {
    return switch (slot) {
      MealSlot.breakfast => '朝食',
      MealSlot.lunch => '昼食',
      MealSlot.dinner => '夕食',
    };
  }

  int _toMinutes(int hour, int minute) {
    return hour * 60 + minute;
  }

  String _timeLabel(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
