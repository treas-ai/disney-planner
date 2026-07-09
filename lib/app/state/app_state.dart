import 'package:flutter/foundation.dart';

import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';

class AppState extends ChangeNotifier {
  TripSettings tripSettings = TripSettings.initial();

  final List<Facility> _selectedFacilities = [];
  final Map<String, PlanPreference> _preferencesByFacilityId = {};

  DaySchedule? daySchedule;

  List<Facility> get selectedFacilities {
    return List.unmodifiable(_selectedFacilities);
  }

  List<PlanPreference> get planPreferences {
    return List.unmodifiable(_preferencesByFacilityId.values);
  }

  int get selectedFacilityCount {
    return _selectedFacilities.length;
  }

  void updateTripSettings(TripSettings settings) {
    tripSettings = settings;
    notifyListeners();
  }

  void addFacility(Facility facility) {
    if (isFacilitySelected(facility.id)) {
      return;
    }

    _selectedFacilities.add(facility);

    _preferencesByFacilityId[facility.id] = PlanPreference.initial(
      facilityId: facility.id,
    );

    notifyListeners();
  }

  void removeFacility(String facilityId) {
    _selectedFacilities.removeWhere(
      (facility) => facility.id == facilityId,
    );

    _preferencesByFacilityId.remove(facilityId);

    notifyListeners();
  }

  bool isFacilitySelected(String facilityId) {
    return _selectedFacilities.any(
      (facility) => facility.id == facilityId,
    );
  }

  PlanPreference? getPreference(String facilityId) {
    return _preferencesByFacilityId[facilityId];
  }

  void updatePreferencePriority({
    required String facilityId,
    required PriorityLevel priority,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      priority: priority,
    );

    notifyListeners();
  }

  void updatePreferencePreferredTime({
    required String facilityId,
    required PreferredTime preferredTime,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      preferredTime: preferredTime,
    );

    notifyListeners();
  }

  void updatePreferenceWaitTolerance({
    required String facilityId,
    required WaitTolerance waitTolerance,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      waitTolerance: waitTolerance,
    );

    notifyListeners();
  }

  void updatePreferenceUseDpa({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      useDpa: value,
    );

    notifyListeners();
  }

  void updatePreferenceUsePriorityPass({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      usePriorityPass: value,
    );

    notifyListeners();
  }

  void updatePreferenceMemo({
    required String facilityId,
    required String memo,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      memo: memo,
    );

    notifyListeners();
  }

  void updateDaySchedule(DaySchedule schedule) {
    daySchedule = schedule;
    notifyListeners();
  }

  void clearDaySchedule() {
    daySchedule = null;
    notifyListeners();
  }
}