import 'package:flutter/foundation.dart';

import '../../data/local/app_state_storage.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/enums/meal_preference.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';
import '../../domain/repositories/facility_repository.dart';
import '../dependency/service_locator.dart';

class AppState extends ChangeNotifier {
  AppState({AppStateStorage? storage, FacilityRepository? facilityRepository})
    : _storage = storage ?? AppStateStorage(),
      _facilityRepository =
          facilityRepository ?? ServiceLocator.facilityRepository;

  final AppStateStorage _storage;
  final FacilityRepository _facilityRepository;

  TripSettings tripSettings = TripSettings.initial();

  final List<Facility> _selectedFacilities = [];
  final Map<String, PlanPreference> _preferencesByFacilityId = {};

  DaySchedule? daySchedule;

  bool isRestored = false;

  List<Facility> get selectedFacilities {
    return List.unmodifiable(_selectedFacilities);
  }

  List<PlanPreference> get planPreferences {
    return List.unmodifiable(_preferencesByFacilityId.values);
  }

  int get selectedFacilityCount {
    return _selectedFacilities.length;
  }

  Future<void> restore() async {
    try {
      final json = await _storage.load();

      if (json == null) {
        return;
      }

      final tripSettingsJson = json['tripSettings'];

      if (tripSettingsJson is Map<String, dynamic>) {
        tripSettings = TripSettings.fromJson(tripSettingsJson);
      }

      final facilityIds = _readStringList(json['selectedFacilityIds']);

      await _restoreSelectedFacilities(facilityIds);

      final rawPreferences = json['planPreferences'];

      if (rawPreferences is List) {
        _preferencesByFacilityId.clear();

        for (final item in rawPreferences) {
          if (item is! Map<String, dynamic>) {
            continue;
          }

          final preference = PlanPreference.fromJson(item);

          if (preference.facilityId.isEmpty) {
            continue;
          }

          if (!isFacilitySelected(preference.facilityId)) {
            continue;
          }

          _preferencesByFacilityId[preference.facilityId] = preference;
        }
      }

      _createMissingPreferences();

      final scheduleJson = json['daySchedule'];

      if (scheduleJson is Map<String, dynamic>) {
        daySchedule = DaySchedule.fromJson(scheduleJson);
      }
    } catch (error, stackTrace) {
      debugPrint('AppStateの復元に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);

      tripSettings = TripSettings.initial();
      _selectedFacilities.clear();
      _preferencesByFacilityId.clear();
      daySchedule = null;
    } finally {
      isRestored = true;
      notifyListeners();
    }
  }

  Future<void> save() async {
    try {
      await _storage.save(toJson());
    } catch (error, stackTrace) {
      debugPrint('AppStateの保存に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> clearSavedState() async {
    await _storage.clear();

    tripSettings = TripSettings.initial();
    _selectedFacilities.clear();
    _preferencesByFacilityId.clear();
    daySchedule = null;

    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    return {
      'tripSettings': tripSettings.toJson(),
      'selectedFacilityIds': _selectedFacilities
          .map((facility) => facility.id)
          .toList(),
      'planPreferences': _preferencesByFacilityId.values
          .map((preference) => preference.toJson())
          .toList(),
      'daySchedule': daySchedule?.toJson(),
    };
  }

  void updateTripSettings(TripSettings settings) {
    tripSettings = settings;
    _saveAndNotify();
  }

  void addFacility(Facility facility) {
    if (isFacilitySelected(facility.id)) {
      return;
    }

    _selectedFacilities.add(facility);

    _preferencesByFacilityId[facility.id] = PlanPreference.initial(
      facilityId: facility.id,
    );

    _saveAndNotify();
  }

  void removeFacility(String facilityId) {
    _selectedFacilities.removeWhere((facility) => facility.id == facilityId);

    _preferencesByFacilityId.remove(facilityId);

    _saveAndNotify();
  }

  bool isFacilitySelected(String facilityId) {
    return _selectedFacilities.any((facility) => facility.id == facilityId);
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

    _preferencesByFacilityId[facilityId] = current.copyWith(priority: priority);

    _saveAndNotify();
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

    _saveAndNotify();
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

    _saveAndNotify();
  }

  void updatePreferenceMealPreference({
    required String facilityId,
    required MealPreference mealPreference,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      mealPreference: mealPreference,
    );

    _saveAndNotify();
  }

  void updatePreferenceUseDpa({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(useDpa: value);

    _saveAndNotify();
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

    _saveAndNotify();
  }

  void updatePreferenceMemo({
    required String facilityId,
    required String memo,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(memo: memo);

    _saveAndNotify();
  }

  void updateDaySchedule(DaySchedule schedule) {
    daySchedule = schedule;
    _saveAndNotify();
  }

  void clearDaySchedule() {
    daySchedule = null;
    _saveAndNotify();
  }

  Future<void> _restoreSelectedFacilities(List<String> facilityIds) async {
    _selectedFacilities.clear();

    for (final facilityId in facilityIds) {
      final facility = await _facilityRepository.getFacilityById(facilityId);

      if (facility != null) {
        _selectedFacilities.add(facility);
      }
    }
  }

  void _createMissingPreferences() {
    for (final facility in _selectedFacilities) {
      _preferencesByFacilityId.putIfAbsent(
        facility.id,
        () => PlanPreference.initial(facilityId: facility.id),
      );
    }
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return [];
    }

    return value.whereType<String>().toList();
  }

  void _saveAndNotify() {
    notifyListeners();
    save();
  }
}
