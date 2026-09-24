import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local/app_state_storage.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/entities/today_access_result.dart';
import '../../domain/entities/today_execution_record.dart';
import '../../domain/entities/wish_item_state.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/lottery_fallback_action.dart';
import '../../domain/enums/meal_preference.dart';
import '../../domain/enums/preferred_time.dart';
import '../../domain/enums/priority_level.dart';
import '../../domain/enums/wait_tolerance.dart';
import '../../domain/enums/wish_importance.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
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

  TripSettings newVisitDayDefaults = TripSettings.initial().copyWith(
    parkId: '',
    visitDateIso: '',
    canUseDpa: false,
    attractionDpaMaxUses: 0,
    hasHappyEntry: false,
    canUseSingleRider: false,
    usesVacationPackage: false,
  );

  final List<String> _visitDayOrder = <String>['day-1'];
  final Map<String, Map<String, dynamic>> _visitDayStates = {};
  String _activeVisitDayId = 'day-1';

  List<String> get visitDayIds => List<String>.unmodifiable(_visitDayOrder);
  String get activeVisitDayId => _activeVisitDayId;
  bool get hasMultipleVisitDays => _visitDayOrder.length > 1;

  TripSettings settingsForVisitDay(String dayId) {
    if (dayId == _activeVisitDayId) return tripSettings;
    final raw = _visitDayStates[dayId]?['tripSettings'];
    if (raw is Map) {
      return TripSettings.fromJson({
        for (final entry in raw.entries) entry.key.toString(): entry.value,
      });
    }
    return TripSettings.initial();
  }

  final List<Facility> _selectedFacilities = [];
  final Set<String> _optionalAdditionFacilityIds = <String>{};
  final Map<String, PlanPreference> _preferencesByFacilityId = {};
  final Map<String, WishItemState> _wishStatesByItemId = {};
  final Set<String> _liveSuspendedFacilityIds = <String>{};
  final Map<String, TodayAccessResult> _todayAccessResultsByKey =
      <String, TodayAccessResult>{};
  final Map<String, TodayExecutionRecord> _todayExecutionRecordsByItemId =
      <String, TodayExecutionRecord>{};

  DaySchedule? daySchedule;
  final List<DaySchedule> _scheduleUndoHistory = [];
  final List<DaySchedule> _scheduleRedoHistory = [];

  bool get canUndoScheduleChange => _scheduleUndoHistory.isNotEmpty;
  bool get canRedoScheduleChange => _scheduleRedoHistory.isNotEmpty;
  int get scheduleHistoryCount => _scheduleUndoHistory.length;

  bool isRestored = false;
  bool isSaving = false;

  List<Facility> get selectedFacilities {
    return List<Facility>.unmodifiable(_selectedFacilities);
  }

  Set<String> get optionalAdditionFacilityIds =>
      Set<String>.unmodifiable(_optionalAdditionFacilityIds);

  bool isOptionalAddition(String facilityId) =>
      _optionalAdditionFacilityIds.contains(facilityId);

  List<PlanPreference> get planPreferences {
    return List<PlanPreference>.unmodifiable(_preferencesByFacilityId.values);
  }

  int get selectedFacilityCount {
    return _selectedFacilities.length;
  }

  List<WishItemState> get wishItemStates {
    return List<WishItemState>.unmodifiable(_wishStatesByItemId.values);
  }

  WishItemState wishStateFor(String itemId) {
    return _wishStatesByItemId[itemId] ?? WishItemState(itemId: itemId);
  }

  int get selectedWishCount {
    return _wishStatesByItemId.values
        .where((state) => state.selected && !state.completed)
        .length;
  }

  Set<String> get liveSuspendedFacilityIds =>
      Set<String>.unmodifiable(_liveSuspendedFacilityIds);

  List<TodayAccessResult> get todayAccessResults =>
      List<TodayAccessResult>.unmodifiable(_todayAccessResultsByKey.values);

  List<TodayExecutionRecord> get todayExecutionRecords =>
      List<TodayExecutionRecord>.unmodifiable(_todayExecutionRecordsByItemId.values);

  TodayExecutionRecord? todayExecutionRecordFor(String scheduleItemId) =>
      _todayExecutionRecordsByItemId[scheduleItemId];

  Set<String> get todayExecutionExcludedFacilityIds =>
      _todayExecutionRecordsByItemId.values
          .map((record) => record.facilityId)
          .whereType<String>()
          .toSet();

  void recordTodayExecution(TodayExecutionRecord record) {
    if (record.scheduleItemId.trim().isEmpty) return;
    _todayExecutionRecordsByItemId[record.scheduleItemId] = record;
    _saveAndNotify();
  }

  void removeTodayExecutionRecord(String scheduleItemId) {
    if (_todayExecutionRecordsByItemId.remove(scheduleItemId) != null) {
      _saveAndNotify();
    }
  }

  TodayAccessResult? todayAccessResultFor(
    String facilityId,
    TodayAccessKind kind,
  ) {
    return _todayAccessResultsByKey['${facilityId}_${kind.name}'];
  }

  void upsertTodayAccessResult(TodayAccessResult result) {
    if (result.facilityId.trim().isEmpty) return;
    _todayAccessResultsByKey[result.key] = result;
    _saveAndNotify();
  }

  void removeTodayAccessResult(String facilityId, TodayAccessKind kind) {
    if (_todayAccessResultsByKey.remove('${facilityId}_${kind.name}') != null) {
      _saveAndNotify();
    }
  }

  void clearTodayAccessResults() {
    if (_todayAccessResultsByKey.isEmpty) return;
    _todayAccessResultsByKey.clear();
    _saveAndNotify();
  }

  Set<String> get releasedFacilityIdsForToday {
    final byFacility = <String, List<TodayAccessResult>>{};
    for (final result in _todayAccessResultsByKey.values) {
      byFacility.putIfAbsent(result.facilityId, () => []).add(result);
    }
    return byFacility.entries
        .where((entry) {
          final hasSuccess = entry.value.any(
            (result) => result.status == TodayAccessStatus.acquired ||
                result.status == TodayAccessStatus.won,
          );
          final hasRelease = entry.value.any(
            (result) => result.status == TodayAccessStatus.lost ||
                result.status == TodayAccessStatus.unavailable ||
                result.status == TodayAccessStatus.skipped,
          );
          return hasRelease && !hasSuccess;
        })
        .map((entry) => entry.key)
        .toSet();
  }

  List<PlanPreference> get effectivePlanPreferencesForToday {
    final resultsByFacility = <String, List<TodayAccessResult>>{};
    for (final result in _todayAccessResultsByKey.values) {
      resultsByFacility.putIfAbsent(result.facilityId, () => []).add(result);
    }

    return _preferencesByFacilityId.values.map((preference) {
      var effective = preference;
      final results = resultsByFacility[preference.facilityId] ??
          const <TodayAccessResult>[];
      Facility? facility;
      for (final value in _selectedFacilities) {
        if (value.id == preference.facilityId) {
          facility = value;
          break;
        }
      }

      for (final result in results) {
        if (result.status == TodayAccessStatus.acquired ||
            result.status == TodayAccessStatus.won) {
          switch (result.kind) {
            case TodayAccessKind.attractionDpa:
              effective = effective.copyWith(
                accessMethod: FacilityAccessMethod.dpa,
                useDpa: true,
                usePriorityPass: false,
                useStandbyPass: false,
                scheduledAccessTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
            case TodayAccessKind.showDpa:
              effective = effective.copyWith(
                accessMethod: FacilityAccessMethod.dpa,
                useDpa: true,
                usePriorityPass: false,
                useStandbyPass: false,
                preferredPerformanceTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
            case TodayAccessKind.priorityPass:
              effective = effective.copyWith(
                accessMethod: FacilityAccessMethod.priorityPass,
                useDpa: false,
                usePriorityPass: true,
                useStandbyPass: false,
                scheduledAccessTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
            case TodayAccessKind.standbyPass:
              effective = effective.copyWith(
                accessMethod: FacilityAccessMethod.standbyPass,
                useDpa: false,
                usePriorityPass: false,
                useStandbyPass: true,
                scheduledAccessTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
            case TodayAccessKind.entryRequest:
              effective = effective.copyWith(
                accessMethod: FacilityAccessMethod.entryRequest,
                preferredPerformanceTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
            case TodayAccessKind.mobileOrder:
              effective = effective.copyWith(
                reservationTime: result.time,
                fixedTimeStatus: result.hasTime
                    ? FixedTimeStatus.confirmed
                    : effective.fixedTimeStatus,
              );
              break;
          }
          continue;
        }

        final failed = result.status == TodayAccessStatus.lost ||
            result.status == TodayAccessStatus.unavailable ||
            result.status == TodayAccessStatus.skipped;
        if (!failed) continue;

        if (result.kind == TodayAccessKind.entryRequest &&
            result.status == TodayAccessStatus.lost &&
            preference.lotteryFallbackAction ==
                LotteryFallbackAction.dpaIfAvailable &&
            facility?.supportsDpa == true) {
          effective = effective.copyWith(
            accessMethod: FacilityAccessMethod.dpa,
            useDpa: true,
            usePriorityPass: false,
            useStandbyPass: false,
            fixedTimeStatus: FixedTimeStatus.none,
            preferredPerformanceTime: '',
          );
          continue;
        }

        FacilityAccessMethod? failedMethod;
        if (result.kind == TodayAccessKind.attractionDpa ||
            result.kind == TodayAccessKind.showDpa) {
          failedMethod = FacilityAccessMethod.dpa;
        } else if (result.kind == TodayAccessKind.priorityPass) {
          failedMethod = FacilityAccessMethod.priorityPass;
        } else if (result.kind == TodayAccessKind.standbyPass) {
          failedMethod = FacilityAccessMethod.standbyPass;
        } else if (result.kind == TodayAccessKind.entryRequest) {
          failedMethod = FacilityAccessMethod.entryRequest;
        }
        if (failedMethod != null && effective.accessMethod == failedMethod) {
          effective = effective.copyWith(
            accessMethod: FacilityAccessMethod.standby,
            useDpa: false,
            usePriorityPass: false,
            useStandbyPass: false,
            fixedTimeStatus: FixedTimeStatus.none,
            scheduledAccessTime: '',
            preferredPerformanceTime: '',
          );
        } else if (result.kind == TodayAccessKind.mobileOrder) {
          effective = effective.copyWith(
            fixedTimeStatus: FixedTimeStatus.none,
            reservationTime: '',
          );
        }
      }
      return effective;
    }).toList(growable: false);
  }

  bool isFacilitySuspendedForToday(String facilityId) {
    return _liveSuspendedFacilityIds.contains(facilityId);
  }

  void suspendFacilityForToday(String facilityId) {
    final normalized = facilityId.trim();
    if (normalized.isEmpty || _liveSuspendedFacilityIds.contains(normalized)) {
      return;
    }
    _liveSuspendedFacilityIds.add(normalized);
    _saveAndNotify();
  }

  void resumeFacilityForToday(String facilityId) {
    if (_liveSuspendedFacilityIds.remove(facilityId)) {
      _saveAndNotify();
    }
  }

  void clearLiveSuspensionsForToday() {
    if (_liveSuspendedFacilityIds.isEmpty) return;
    _liveSuspendedFacilityIds.clear();
    _saveAndNotify();
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

  List<Facility> requiredSelectedFacilitiesForPark(String parkId) {
    return List<Facility>.unmodifiable(
      _selectedFacilities.where(
        (facility) =>
            facility.parkId == parkId &&
            !_optionalAdditionFacilityIds.contains(facility.id),
      ).toList(growable: false),
    );
  }

  int requiredSelectedFacilityCountForPark(String parkId) {
    return requiredSelectedFacilitiesForPark(parkId).length;
  }

  void clearRequiredSelectedFacilitiesForPark(String parkId) {
    final facilityIds = requiredSelectedFacilitiesForPark(parkId)
        .map((facility) => facility.id)
        .toSet();
    if (facilityIds.isEmpty) return;
    _selectedFacilities.removeWhere(
      (facility) => facilityIds.contains(facility.id),
    );
    for (final facilityId in facilityIds) {
      _preferencesByFacilityId.remove(facilityId);
    }
    _todayAccessResultsByKey.removeWhere(
      (_, value) => facilityIds.contains(value.facilityId),
    );
    daySchedule = null;
    _saveAndNotify();
  }

  Future<void> restore() async {
    try {
      final json = await _storage.load();

      if (json == null) {
        return;
      }

      final rawDefaults = json['newVisitDayDefaults'];
      if (rawDefaults is Map) {
        newVisitDayDefaults = TripSettings.fromJson({
          for (final entry in rawDefaults.entries) entry.key.toString(): entry.value,
        }).copyWith(parkId: '', visitDateIso: '');
      }

      final rawVisitDayStates = json['visitDayStates'];
      if (rawVisitDayStates is Map && rawVisitDayStates.isNotEmpty) {
        _visitDayStates.clear();
        for (final entry in rawVisitDayStates.entries) {
          if (entry.value is Map) {
            _visitDayStates[entry.key.toString()] = {
              for (final stateEntry in (entry.value as Map).entries)
                stateEntry.key.toString(): stateEntry.value,
            };
          }
        }
        final order = _readStringList(json['visitDayOrder']);
        _visitDayOrder
          ..clear()
          ..addAll(order.where(_visitDayStates.containsKey));
        if (_visitDayOrder.isEmpty) {
          _visitDayOrder.addAll(_visitDayStates.keys);
        }
        final savedActive = json['activeVisitDayId'] as String?;
        _activeVisitDayId = savedActive != null && _visitDayStates.containsKey(savedActive)
            ? savedActive
            : _visitDayOrder.first;
        await _restoreDayState(_visitDayStates[_activeVisitDayId]!);
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
      _optionalAdditionFacilityIds
        ..clear()
        ..addAll(_readStringList(json['optionalAdditionFacilityIds']));

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

      _wishStatesByItemId.clear();
      _liveSuspendedFacilityIds
        ..clear()
        ..addAll(_readStringList(json['liveSuspendedFacilityIds']));
      _restoreTodayAccessResults(json['todayAccessResults']);
      _restoreTodayExecutionRecords(json['todayExecutionRecords']);
      final rawWishStates = json['wishItemStates'];
      if (rawWishStates is List) {
        for (final item in rawWishStates) {
          if (item is! Map) {
            continue;
          }
          final state = WishItemState.fromJson({
            for (final entry in item.entries) entry.key.toString(): entry.value,
          });
          if (state.itemId.isNotEmpty) {
            _wishStatesByItemId[state.itemId] = state;
          }
        }
      }

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

      _scheduleUndoHistory
        ..clear()
        ..addAll(_readScheduleList(json['scheduleUndoHistory']));
      _scheduleRedoHistory
        ..clear()
        ..addAll(_readScheduleList(json['scheduleRedoHistory']));

      _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
    } catch (error, stackTrace) {
      debugPrint('AppStateの復元に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      tripSettings = TripSettings.initial().copyWith(
        parkId: '',
        attractionDpaMaxUses: 0,
      );
      _selectedFacilities.clear();
      _preferencesByFacilityId.clear();
      _wishStatesByItemId.clear();
      _liveSuspendedFacilityIds.clear();
      _todayAccessResultsByKey.clear();
      _todayExecutionRecordsByItemId.clear();
      daySchedule = null;
      _scheduleUndoHistory.clear();
      _scheduleRedoHistory.clear();
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
    newVisitDayDefaults = TripSettings.initial().copyWith(
      parkId: '',
      visitDateIso: '',
      canUseDpa: false,
      attractionDpaMaxUses: 0,
      hasHappyEntry: false,
      canUseSingleRider: false,
      usesVacationPackage: false,
    );
    _selectedFacilities.clear();
    _preferencesByFacilityId.clear();
    _wishStatesByItemId.clear();
    _liveSuspendedFacilityIds.clear();
    _todayAccessResultsByKey.clear();
    _todayExecutionRecordsByItemId.clear();
    daySchedule = null;
    _scheduleUndoHistory.clear();
    _scheduleRedoHistory.clear();
    _visitDayOrder
      ..clear()
      ..add('day-1');
    _visitDayStates.clear();
    _activeVisitDayId = 'day-1';

    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
    return {
      'tripSettings': tripSettings.toJson(),
      'newVisitDayDefaults': newVisitDayDefaults.toJson(),
      'selectedFacilityIds': _selectedFacilities
          .map((facility) => facility.id)
          .toList(),
      'optionalAdditionFacilityIds': _optionalAdditionFacilityIds.toList(),
      'planPreferences': _preferencesByFacilityId.values
          .map((preference) => preference.toJson())
          .toList(),
      'wishItemStates': _wishStatesByItemId.values
          .map((state) => state.toJson())
          .toList(),
      'liveSuspendedFacilityIds': _liveSuspendedFacilityIds.toList(),
      'todayAccessResults': _todayAccessResultsByKey.values
          .map((value) => value.toJson())
          .toList(),
      'todayExecutionRecords': _todayExecutionRecordsByItemId.values
          .map((value) => value.toJson())
          .toList(),
      'daySchedule': daySchedule?.toJson(),
      'scheduleUndoHistory': _scheduleUndoHistory
          .map((schedule) => schedule.toJson())
          .toList(),
      'scheduleRedoHistory': _scheduleRedoHistory
          .map((schedule) => schedule.toJson())
          .toList(),
      'visitDayOrder': _visitDayOrder,
      'activeVisitDayId': _activeVisitDayId,
      'visitDayStates': _visitDayStates,
    };
  }

  Future<void> addVisitDay({required DateTime date, String parkId = ''}) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final settings = newVisitDayDefaults.copyWith(
      visitDateIso: normalized.toIso8601String(),
      parkId: parkId,
    );

    if (tripSettings.visitDate == null && _visitDayOrder.length == 1) {
      tripSettings = settings;
      _selectedFacilities.clear();
      _optionalAdditionFacilityIds.clear();
      _preferencesByFacilityId.clear();
      _wishStatesByItemId.clear();
      _liveSuspendedFacilityIds.clear();
      _todayAccessResultsByKey.clear();
      _todayExecutionRecordsByItemId.clear();
      daySchedule = null;
      _scheduleUndoHistory.clear();
      _scheduleRedoHistory.clear();
      _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
      _saveAndNotify();
      return;
    }

    _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
    var dayId = normalized.toIso8601String().split('T').first;
    var suffix = 2;
    while (_visitDayStates.containsKey(dayId)) {
      dayId = '${normalized.toIso8601String().split('T').first}-$suffix';
      suffix++;
    }
    _visitDayStates[dayId] = _emptyDayState(settings);
    _visitDayOrder.add(dayId);
    _activeVisitDayId = dayId;
    await _restoreDayState(_visitDayStates[dayId]!);
    _saveAndNotify();
  }

  void updateNewVisitDayDefaults(TripSettings settings) {
    newVisitDayDefaults = settings.copyWith(parkId: '', visitDateIso: '');
    _saveAndNotify();
  }

  Future<void> switchVisitDay(String dayId) async {
    if (dayId == _activeVisitDayId || !_visitDayStates.containsKey(dayId)) return;
    _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
    _activeVisitDayId = dayId;
    await _restoreDayState(_visitDayStates[dayId]!);
    notifyListeners();
    await save();
  }

  Future<void> removeVisitDay(String dayId) async {
    if (!_visitDayStates.containsKey(dayId) && dayId != _activeVisitDayId) return;

    if (_visitDayOrder.length <= 1) {
      // Keep one internal blank slot so the rest of the app can continue to use
      // an active day id. User-facing state is a genuinely unconfigured trip.
      tripSettings = TripSettings.initial().copyWith(
        parkId: '',
        attractionDpaMaxUses: 0,
      );
      _selectedFacilities.clear();
      _optionalAdditionFacilityIds.clear();
      _preferencesByFacilityId.clear();
      _wishStatesByItemId.clear();
      _liveSuspendedFacilityIds.clear();
      _todayAccessResultsByKey.clear();
      _todayExecutionRecordsByItemId.clear();
      daySchedule = null;
      _scheduleUndoHistory.clear();
      _scheduleRedoHistory.clear();
      _visitDayOrder
        ..clear()
        ..add('day-1');
      _visitDayStates.clear();
      _activeVisitDayId = 'day-1';
      _saveAndNotify();
      return;
    }

    final index = _visitDayOrder.indexOf(dayId);
    _visitDayOrder.remove(dayId);
    _visitDayStates.remove(dayId);
    if (_activeVisitDayId == dayId) {
      _activeVisitDayId =
          _visitDayOrder[index.clamp(0, _visitDayOrder.length - 1).toInt()];
      await _restoreDayState(_visitDayStates[_activeVisitDayId]!);
    }
    _saveAndNotify();
  }

  void updateActiveVisitDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final previousDate = tripSettings.visitDate;
    final dateChanged = previousDate == null ||
        previousDate.year != normalized.year ||
        previousDate.month != normalized.month ||
        previousDate.day != normalized.day;
    tripSettings = tripSettings.copyWith(visitDateIso: normalized.toIso8601String());
    if (dateChanged) {
      _liveSuspendedFacilityIds.clear();
      _todayAccessResultsByKey.clear();
      _todayExecutionRecordsByItemId.clear();
    }
    daySchedule = null;
    _saveAndNotify();
  }

  void updateTripSettings(TripSettings settings) {
    final visitContextChanged =
        settings.parkId != tripSettings.parkId ||
        settings.visitDateIso != tripSettings.visitDateIso;
    tripSettings = settings;
    if (visitContextChanged) {
      _liveSuspendedFacilityIds.clear();
      _todayAccessResultsByKey.clear();
      _todayExecutionRecordsByItemId.clear();
    }
    daySchedule = null;
    _saveAndNotify();
  }

  void addFacility(Facility facility) {
    if (isFacilitySelected(facility.id)) {
      return;
    }

    _selectedFacilities.add(facility);
    _optionalAdditionFacilityIds.remove(facility.id);

    final initialPreference = PlanPreference.initial(facilityId: facility.id);
    _preferencesByFacilityId[facility.id] = facility.requiresEntryRequest
        ? initialPreference.copyWith(
            accessMethod: FacilityAccessMethod.entryRequest,
            fixedTimeStatus: FixedTimeStatus.planned,
            lotteryFallbackAction: LotteryFallbackAction.dpaIfAvailable,
          )
        : initialPreference;

    daySchedule = null;

    _saveAndNotify();
  }

  void addOptionalFacility(Facility facility) {
    if (!isFacilitySelected(facility.id)) {
      _selectedFacilities.add(facility);
      final initialPreference = PlanPreference.initial(facilityId: facility.id);
      _preferencesByFacilityId[facility.id] = facility.requiresEntryRequest
          ? initialPreference.copyWith(
              accessMethod: FacilityAccessMethod.entryRequest,
              fixedTimeStatus: FixedTimeStatus.planned,
              lotteryFallbackAction: LotteryFallbackAction.dpaIfAvailable,
            )
          : initialPreference;
    }
    _optionalAdditionFacilityIds.add(facility.id);
    daySchedule = null;
    _saveAndNotify();
  }

  void addFacilityRepeat(Facility facility) {
    // A repeated experience is intentionally represented by another occurrence
    // of the same facility. Preferences remain shared by facility ID.
    _selectedFacilities.add(facility);
    _preferencesByFacilityId.putIfAbsent(
      facility.id,
      () {
        final initialPreference = PlanPreference.initial(facilityId: facility.id);
        return facility.requiresEntryRequest
            ? initialPreference.copyWith(
                accessMethod: FacilityAccessMethod.entryRequest,
                fixedTimeStatus: FixedTimeStatus.planned,
                lotteryFallbackAction: LotteryFallbackAction.dpaIfAvailable,
              )
            : initialPreference;
      },
    );
    daySchedule = null;
    _saveAndNotify();
  }

  void removeOneFacilityOccurrence(String facilityId) {
    final index = _selectedFacilities.lastIndexWhere(
      (facility) => facility.id == facilityId,
    );
    if (index < 0) return;
    _selectedFacilities.removeAt(index);
    final stillSelected =
        _selectedFacilities.any((facility) => facility.id == facilityId);
    if (!stillSelected) {
      _optionalAdditionFacilityIds.remove(facilityId);
      _preferencesByFacilityId.remove(facilityId);
      _todayAccessResultsByKey.removeWhere(
        (_, value) => value.facilityId == facilityId,
      );
    }
    daySchedule = null;
    _saveAndNotify();
  }

  void clearSelectedFacilitiesForPark(String parkId) {
    final facilityIds = _selectedFacilities
        .where((facility) => facility.parkId == parkId)
        .map((facility) => facility.id)
        .toSet();

    if (facilityIds.isEmpty) {
      return;
    }

    _selectedFacilities.removeWhere((facility) => facilityIds.contains(facility.id));
    _optionalAdditionFacilityIds.removeAll(facilityIds);

    for (final facilityId in facilityIds) {
      _preferencesByFacilityId.remove(facilityId);
    }
    _todayAccessResultsByKey.removeWhere(
      (_, value) => facilityIds.contains(value.facilityId),
    );

    daySchedule = null;
    _saveAndNotify();
  }

  void removeFacility(String facilityId) {
    final beforeCount = _selectedFacilities.length;

    _selectedFacilities.removeWhere((facility) => facility.id == facilityId);
    _optionalAdditionFacilityIds.remove(facilityId);

    if (beforeCount == _selectedFacilities.length) {
      return;
    }

    _preferencesByFacilityId.remove(facilityId);
    _todayAccessResultsByKey.removeWhere(
      (_, value) => value.facilityId == facilityId,
    );

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

  void updatePreferenceAccessMethod({
    required String facilityId,
    required FacilityAccessMethod accessMethod,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      accessMethod: accessMethod,
      useDpa: accessMethod == FacilityAccessMethod.dpa,
      usePriorityPass: accessMethod == FacilityAccessMethod.priorityPass,
      useStandbyPass: accessMethod == FacilityAccessMethod.standbyPass,
      fixedTimeStatus: FixedTimeStatus.none,
      preferredPerformanceTime: '',
      reservationTime: '',
      scheduledAccessTime: '',
      clearSelectedPerformanceIndex: true,
      lotteryFallbackAction: accessMethod == FacilityAccessMethod.entryRequest
          ? LotteryFallbackAction.dpaIfAvailable
          : current.lotteryFallbackAction,
    );

    _invalidateScheduleAndSave();
  }

  void updatePreferencePreferredPerformanceTime({
    required String facilityId,
    required String value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      preferredPerformanceTime: value.trim(),
    );

    _invalidateScheduleAndSave();
  }

  void updatePreferenceReservationTime({
    required String facilityId,
    required String value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      reservationTime: value.trim(),
    );

    _invalidateScheduleAndSave();
  }

  void updatePreferenceScheduledAccessTime({
    required String facilityId,
    required String value,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      scheduledAccessTime: value.trim(),
    );

    _invalidateScheduleAndSave();
  }

  void updatePreferenceFixedTimeStatus({
    required String facilityId,
    required FixedTimeStatus status,
  }) {
    final current = _preferencesByFacilityId[facilityId];
    if (current == null) return;

    _preferencesByFacilityId[facilityId] = current.copyWith(
      fixedTimeStatus: status,
      preferredPerformanceTime: status == FixedTimeStatus.confirmed
          ? current.preferredPerformanceTime
          : '',
      reservationTime: status == FixedTimeStatus.confirmed
          ? current.reservationTime
          : '',
      scheduledAccessTime: status == FixedTimeStatus.confirmed
          ? current.scheduledAccessTime
          : '',
      clearSelectedPerformanceIndex: status != FixedTimeStatus.confirmed,
    );
    _invalidateScheduleAndSave();
  }

  void updatePreferenceSelectedPerformance({
    required String facilityId,
    required int? performanceIndex,
    required String startTime,
  }) {
    final current = _preferencesByFacilityId[facilityId];
    if (current == null) return;

    _preferencesByFacilityId[facilityId] = current.copyWith(
      fixedTimeStatus: startTime.trim().isEmpty
          ? FixedTimeStatus.none
          : FixedTimeStatus.confirmed,
      selectedPerformanceIndex: performanceIndex,
      clearSelectedPerformanceIndex: performanceIndex == null,
      preferredPerformanceTime: startTime.trim(),
    );
    _invalidateScheduleAndSave();
  }

  void updatePreferenceLotteryFallbackAction({
    required String facilityId,
    required LotteryFallbackAction action,
  }) {
    final current = _preferencesByFacilityId[facilityId];

    if (current == null) {
      return;
    }

    _preferencesByFacilityId[facilityId] = current.copyWith(
      lotteryFallbackAction: action,
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

  void toggleWishSelected(String itemId, bool selected) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(selected: selected);
    _saveAndNotify();
  }

  void toggleWishCompleted(String itemId, bool completed) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(completed: completed);
    _saveAndNotify();
  }

  void updateWishPriority(String itemId, int priority) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(priority: priority);
    _saveAndNotify();
  }

  void updateWishImportance(String itemId, WishImportance importance) {
    final priority = switch (importance) {
      WishImportance.optional => 2,
      WishImportance.normal => 3,
      WishImportance.mustDo => 5,
    };
    updateWishPriority(itemId, priority);
  }

  void updateWishPreferredTime(String itemId, PreferredTime preferredTime) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(preferredTime: preferredTime);
    _saveAndNotify();
  }

  void updateWishWaitTolerance(String itemId, WaitTolerance waitTolerance) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(waitTolerance: waitTolerance);
    _saveAndNotify();
  }

  void updateWishTargetCount(String itemId, int targetCount) {
    final current = wishStateFor(itemId);
    _wishStatesByItemId[itemId] = current.copyWith(
      targetCount: targetCount.clamp(1, 5),
      repeatAllowed: targetCount > 1,
    );
    _saveAndNotify();
  }

  void selectWishItems(Iterable<String> itemIds) {
    for (final itemId in itemIds) {
      final current = wishStateFor(itemId);
      _wishStatesByItemId[itemId] = current.copyWith(selected: true);
    }
    _saveAndNotify();
  }

  void clearWishSelection() {
    final keys = _wishStatesByItemId.keys.toList(growable: false);
    for (final key in keys) {
      final current = _wishStatesByItemId[key]!;
      _wishStatesByItemId[key] = current.copyWith(selected: false);
    }
    _saveAndNotify();
  }

  void updateDaySchedule(DaySchedule schedule) {
    _recordCurrentSchedule();
    daySchedule = schedule;
    _scheduleRedoHistory.clear();
    _saveAndNotify();
  }

  /// DEBUG-only schedule swap used by the unified regression console.
  ///
  /// This intentionally does not touch undo/redo history. It lets the debug
  /// console generate a fresh PRE-TRIP reference and then restore the user's
  /// current TODAY schedule without turning verification into a user action.
  void debugReplaceDayScheduleWithoutHistory(DaySchedule? schedule) {
    assert(kDebugMode);
    daySchedule = schedule;
    _saveAndNotify();
  }

  void applyRecalculatedSchedule(DaySchedule schedule) {
    _recordCurrentSchedule();
    daySchedule = schedule;
    _scheduleRedoHistory.clear();
    _saveAndNotify();
  }

  void undoLastScheduleChange() {
    if (_scheduleUndoHistory.isEmpty) {
      return;
    }
    final current = daySchedule;
    if (current != null) {
      _scheduleRedoHistory.add(current);
    }
    daySchedule = _scheduleUndoHistory.removeLast();
    _saveAndNotify();
  }

  void redoLastScheduleChange() {
    if (_scheduleRedoHistory.isEmpty) {
      return;
    }
    final current = daySchedule;
    if (current != null) {
      _scheduleUndoHistory.add(current);
    }
    daySchedule = _scheduleRedoHistory.removeLast();
    _saveAndNotify();
  }

  void clearScheduleUndoHistory() {
    if (_scheduleUndoHistory.isEmpty && _scheduleRedoHistory.isEmpty) {
      return;
    }
    _scheduleUndoHistory.clear();
    _scheduleRedoHistory.clear();
    notifyListeners();
  }

  void clearDaySchedule() {
    if (daySchedule == null) {
      return;
    }

    _recordCurrentSchedule();
    daySchedule = null;
    _scheduleRedoHistory.clear();
    _saveAndNotify();
  }

  String exportBackupJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appState': toJson(),
    });
  }

  String exportSharedPlanJson() {
    final schedule = daySchedule;
    if (schedule == null) {
      throw StateError('共有できるプランがありません。');
    }

    return jsonEncode({
      'shareSchemaVersion': 1,
      'kind': 'plan',
      'exportedAt': DateTime.now().toIso8601String(),
      'tripSettings': tripSettings.toJson(),
      'daySchedule': schedule.toJson(),
    });
  }

  Future<void> importBackupJson(String value) async {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('バックアップ形式が正しくありません。');
    }

    final rawState = decoded['appState'] ?? decoded;
    if (rawState is! Map) {
      throw const FormatException('アプリデータが含まれていません。');
    }

    final converted = <String, dynamic>{
      for (final entry in rawState.entries) entry.key.toString(): entry.value,
    };
    await _storage.save(converted);
    await restore();
  }

  Future<String> importSharedData(Map<String, dynamic> shared) async {
    final kind = shared['kind']?.toString();

    if (kind == 'backup') {
      final payload = shared['payload'];
      if (payload is! Map) {
        throw const FormatException('バックアップ本体が含まれていません。');
      }
      await importBackupJson(jsonEncode(payload));
      return 'すべての設定とプラン';
    }

    if (kind == 'plan') {
      final rawSettings = shared['tripSettings'];
      final rawSchedule = shared['daySchedule'];
      if (rawSettings is! Map || rawSchedule is! Map) {
        throw const FormatException('プラン共有データが不足しています。');
      }

      tripSettings = TripSettings.fromJson({
        for (final entry in rawSettings.entries)
          entry.key.toString(): entry.value,
      });
      _recordCurrentSchedule();
      daySchedule = DaySchedule.fromJson({
        for (final entry in rawSchedule.entries)
          entry.key.toString(): entry.value,
      });
      _scheduleRedoHistory.clear();
      await save();
      notifyListeners();
      return '現在のプラン';
    }

    if (shared.containsKey('appState') || shared.containsKey('tripSettings')) {
      await importBackupJson(jsonEncode(shared));
      return 'すべての設定とプラン';
    }

    throw const FormatException('対応していない共有データです。');
  }

  void _recordCurrentSchedule() {
    final current = daySchedule;
    if (current == null) {
      return;
    }
    _scheduleUndoHistory.add(current);
    if (_scheduleUndoHistory.length > 10) {
      _scheduleUndoHistory.removeAt(0);
    }
  }

  List<DaySchedule> _readScheduleList(dynamic value) {
    if (value is! List) {
      return <DaySchedule>[];
    }
    final schedules = <DaySchedule>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        schedules.add(DaySchedule.fromJson(item));
      } else if (item is Map) {
        schedules.add(
          DaySchedule.fromJson({
            for (final entry in item.entries) entry.key.toString(): entry.value,
          }),
        );
      }
    }
    return schedules;
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
        () {
          final initialPreference = PlanPreference.initial(
            facilityId: facility.id,
          );
          return facility.requiresEntryRequest
              ? initialPreference.copyWith(
                  accessMethod: FacilityAccessMethod.entryRequest,
                  fixedTimeStatus: FixedTimeStatus.planned,
                  lotteryFallbackAction: LotteryFallbackAction.dpaIfAvailable,
                )
              : initialPreference;
        },
      );
    }
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value.whereType<String>().toList(growable: false);
  }

  Map<String, dynamic> _currentDayStateJson() {
    return {
      'tripSettings': tripSettings.toJson(),
      'selectedFacilityIds': _selectedFacilities.map((facility) => facility.id).toList(),
      'optionalAdditionFacilityIds': _optionalAdditionFacilityIds.toList(),
      'planPreferences': _preferencesByFacilityId.values.map((value) => value.toJson()).toList(),
      'wishItemStates': _wishStatesByItemId.values.map((value) => value.toJson()).toList(),
      'liveSuspendedFacilityIds': _liveSuspendedFacilityIds.toList(),
      'todayAccessResults': _todayAccessResultsByKey.values
          .map((value) => value.toJson())
          .toList(),
      'todayExecutionRecords': _todayExecutionRecordsByItemId.values
          .map((value) => value.toJson())
          .toList(),
      'daySchedule': daySchedule?.toJson(),
      'scheduleUndoHistory': _scheduleUndoHistory.map((value) => value.toJson()).toList(),
      'scheduleRedoHistory': _scheduleRedoHistory.map((value) => value.toJson()).toList(),
    };
  }

  Map<String, dynamic> _emptyDayState(TripSettings settings) {
    return {
      'tripSettings': settings.toJson(),
      'selectedFacilityIds': <String>[],
      'optionalAdditionFacilityIds': <String>[],
      'planPreferences': <dynamic>[],
      'wishItemStates': <dynamic>[],
      'liveSuspendedFacilityIds': <String>[],
      'todayAccessResults': <dynamic>[],
      'todayExecutionRecords': <dynamic>[],
      'daySchedule': null,
      'scheduleUndoHistory': <dynamic>[],
      'scheduleRedoHistory': <dynamic>[],
    };
  }

  Future<void> _restoreDayState(Map<String, dynamic> state) async {
    final rawSettings = state['tripSettings'];
    if (rawSettings is Map) {
      tripSettings = TripSettings.fromJson({
        for (final entry in rawSettings.entries) entry.key.toString(): entry.value,
      });
    }
    await _restoreSelectedFacilities(_readStringList(state['selectedFacilityIds']));
    _optionalAdditionFacilityIds
      ..clear()
      ..addAll(_readStringList(state['optionalAdditionFacilityIds']));    _preferencesByFacilityId.clear();
    final rawPreferences = state['planPreferences'];
    if (rawPreferences is List) {
      for (final item in rawPreferences.whereType<Map>()) {
        final preference = PlanPreference.fromJson({
          for (final entry in item.entries) entry.key.toString(): entry.value,
        });
        if (isFacilitySelected(preference.facilityId)) {
          _preferencesByFacilityId[preference.facilityId] = preference;
        }
      }
    }
    _createMissingPreferences();
    _wishStatesByItemId.clear();
    _liveSuspendedFacilityIds
      ..clear()
      ..addAll(_readStringList(state['liveSuspendedFacilityIds']));
    _restoreTodayAccessResults(state['todayAccessResults']);
    _restoreTodayExecutionRecords(state['todayExecutionRecords']);
    final rawWishStates = state['wishItemStates'];
    if (rawWishStates is List) {
      for (final item in rawWishStates.whereType<Map>()) {
        final value = WishItemState.fromJson({
          for (final entry in item.entries) entry.key.toString(): entry.value,
        });
        if (value.itemId.isNotEmpty) _wishStatesByItemId[value.itemId] = value;
      }
    }
    final rawSchedule = state['daySchedule'];
    daySchedule = rawSchedule is Map
        ? DaySchedule.fromJson({for (final entry in rawSchedule.entries) entry.key.toString(): entry.value})
        : null;
    _scheduleUndoHistory
      ..clear()
      ..addAll(_readScheduleList(state['scheduleUndoHistory']));
    _scheduleRedoHistory
      ..clear()
      ..addAll(_readScheduleList(state['scheduleRedoHistory']));
  }

  void _restoreTodayExecutionRecords(dynamic raw) {
    _todayExecutionRecordsByItemId.clear();
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      final record = TodayExecutionRecord.fromJson({
        for (final entry in item.entries) entry.key.toString(): entry.value,
      });
      if (record.scheduleItemId.isNotEmpty) {
        _todayExecutionRecordsByItemId[record.scheduleItemId] = record;
      }
    }
  }

  void _restoreTodayAccessResults(dynamic raw) {
    _todayAccessResultsByKey.clear();
    if (raw is! List) return;
    for (final item in raw.whereType<Map>()) {
      final result = TodayAccessResult.fromJson({
        for (final entry in item.entries) entry.key.toString(): entry.value,
      });
      if (result.facilityId.isNotEmpty) {
        _todayAccessResultsByKey[result.key] = result;
      }
    }
  }

  void _invalidateScheduleAndSave() {
    daySchedule = null;
    _saveAndNotify();
  }

  void _saveAndNotify() {
    _visitDayStates[_activeVisitDayId] = _currentDayStateJson();
    notifyListeners();
    save();
  }
}
