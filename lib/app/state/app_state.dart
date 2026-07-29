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
  bool isSaving = false;

  List<Facility> get selectedFacilities {
    return List<Facility>.unmodifiable(_selectedFacilities);
  }

  List<PlanPreference> get planPreferences {
    return List<PlanPreference>.unmodifiable(_preferencesByFacilityId.values);
  }

  int get selectedFacilityCount {
    return _selectedFacilities.length;
  }

  List<Facility> selectedFacilitiesForPark(String parkId) {
    return List<Facility>.unmodifiable(
      _selectedFacilities
          .where((facility) => facility.parkId == parkId)
          .toList(growable: false),
    );
  }

  int selectedFacilityCountForPark(String parkId) {
    return _selectedFacilities
        .where((facility) => facility.parkId == parkId)
        .length;
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
      } else if (tripSettingsJson is Map) {
        final convertedSettings = <String, dynamic>{};

        for (final entry in tripSettingsJson.entries) {
          convertedSettings[entry.key.toString()] = entry.value;
        }

        tripSettings = TripSettings.fromJson(convertedSettings);
      }

      final facilityIds = _readStringList(json['selectedFacilityIds']);

      await _restoreSelectedFacilities(facilityIds);

      final rawPreferences = json['planPreferences'];

      if (rawPreferences is List) {
        _preferencesByFacilityId.clear();

        for (final item in rawPreferences) {
          if (item is! Map) {
            continue;
          }

          final convertedItem = <String, dynamic>{};

          for (final entry in item.entries) {
            convertedItem[entry.key.toString()] = entry.value;
          }

          final preference = PlanPreference.fromJson(convertedItem);

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
      } else if (scheduleJson is Map) {
        final convertedSchedule = <String, dynamic>{};

        for (final entry in scheduleJson.entries) {
          convertedSchedule[entry.key.toString()] = entry.value;
        }

        daySchedule = DaySchedule.fromJson(convertedSchedule);
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
    if (isSaving) {
      return;
    }

    isSaving = true;
    notifyListeners();

    try {
      await _storage.save(toJson());
    } catch (error, stackTrace) {
      debugPrint('AppStateの保存に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isSaving = false;
      notifyListeners();
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
    daySchedule = null;
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

    daySchedule = null;

    _saveAndNotify();
  }

  void removeFacility(String facilityId) {
    final beforeCount = _selectedFacilities.length;

    _selectedFacilities.removeWhere((facility) => facility.id == facilityId);

    if (beforeCount == _selectedFacilities.length) {
      return;
    }

    _preferencesByFacilityId.remove(facilityId);

    daySchedule = null;

    _saveAndNotify();
  }

  void reorderSelectedFacilitiesForPark({
    required String parkId,
    required int oldIndex,
    required int newIndex,
  }) {
    final parkFacilities = _selectedFacilities
        .where((facility) => facility.parkId == parkId)
        .toList(growable: true);

    if (parkFacilities.length < 2) {
      return;
    }

    if (oldIndex < 0 || oldIndex >= parkFacilities.length) {
      return;
    }

    if (newIndex < 0 || newIndex > parkFacilities.length) {
      return;
    }

    var adjustedNewIndex = newIndex;

    if (adjustedNewIndex > oldIndex) {
      adjustedNewIndex--;
    }

    if (adjustedNewIndex == oldIndex) {
      return;
    }

    final movedFacility = parkFacilities.removeAt(oldIndex);

    parkFacilities.insert(adjustedNewIndex, movedFacility);

    final reorderedFacilities = <Facility>[];
    var currentParkIndex = 0;

    for (final facility in _selectedFacilities) {
      if (facility.parkId == parkId) {
        reorderedFacilities.add(parkFacilities[currentParkIndex]);

        currentParkIndex++;
      } else {
        reorderedFacilities.add(facility);
      }
    }

    _selectedFacilities
      ..clear()
      ..addAll(reorderedFacilities);

    daySchedule = null;

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

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
  }

  void updatePreferenceUseStandbyPass({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      useStandbyPass: value,
    );

    _invalidateScheduleAndSave();
  }

  void updatePreferencePrioritizeCapsuleToy({
    required String facilityId,
    required bool value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      prioritizeCapsuleToy: value,
    );

    _invalidateScheduleAndSave();
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

    _invalidateScheduleAndSave();
  }

  void updateDaySchedule(DaySchedule schedule) {
    daySchedule = schedule;
    _saveAndNotify();
  }

  void clearDaySchedule() {
    if (daySchedule == null) {
      return;
    }

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
      return <String>[];
    }

    return value.whereType<String>().toList(growable: false);
  }

  void _invalidateScheduleAndSave() {
    daySchedule = null;
    _saveAndNotify();
  }

  void _saveAndNotify() {
    notifyListeners();
    save();
  }
}
