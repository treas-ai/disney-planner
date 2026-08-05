import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local/app_state_storage.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/trip_settings.dart';
import '../../domain/entities/wish_item_state.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../domain/enums/lottery_fallback_action.dart';
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
  final Map<String, WishItemState> _wishStatesByItemId = {};

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

      _wishStatesByItemId.clear();
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
    } catch (error, stackTrace) {
      debugPrint('AppStateの復元に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      tripSettings = TripSettings.initial();
      _selectedFacilities.clear();
      _preferencesByFacilityId.clear();
      _wishStatesByItemId.clear();
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
    _selectedFacilities.clear();
    _preferencesByFacilityId.clear();
    _wishStatesByItemId.clear();
    daySchedule = null;
    _scheduleUndoHistory.clear();
    _scheduleRedoHistory.clear();

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
      'wishItemStates': _wishStatesByItemId.values
          .map((state) => state.toJson())
          .toList(),
      'daySchedule': daySchedule?.toJson(),
      'scheduleUndoHistory': _scheduleUndoHistory
          .map((schedule) => schedule.toJson())
          .toList(),
      'scheduleRedoHistory': _scheduleRedoHistory
          .map((schedule) => schedule.toJson())
          .toList(),
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
