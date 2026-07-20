import 'package:flutter/foundation.dart';

import '../../data/local/app_state_storage.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';
import '../dependency/service_locator.dart';

class AppState extends ChangeNotifier {
  AppState({AppStateStorage? storage})
    : _storage = storage ?? AppStateStorage();

  final AppStateStorage _storage;

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
    final json = await _storage.load();

    if (json == null) {
      isRestored = true;
      notifyListeners();
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
        if (item is Map<String, dynamic>) {
          final preference = PlanPreference.fromJson(item);

          if (preference.facilityId.isNotEmpty) {
            _preferencesByFacilityId[preference.facilityId] = preference;
          }
        }
      }
    }

    final scheduleJson = json['daySchedule'];
    if (scheduleJson is Map<String, dynamic>) {
      daySchedule = DaySchedule.fromJson(scheduleJson);
    }

    isRestored = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _storage.save(toJson());
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

    final repository = ServiceLocator.facilityRepository;

    if (repository is FacilityRepositoryImpl) {
      final facilities = await repository.getFacilities();

      for (final facilityId in facilityIds) {
        for (final facility in facilities) {
          if (facility.id == facilityId) {
            _selectedFacilities.add(facility);
            break;
          }
        }
      }
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
