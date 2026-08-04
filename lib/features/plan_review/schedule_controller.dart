import 'package:flutter/material.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_validation_issue.dart';
import '../../domain/enums/fixed_time_status.dart';
import '../../data/local/local_performance_schedule_repository.dart';
import '../../domain/services/official_performance_preference_resolver.dart';
import '../../domain/services/schedule_engine.dart';
import '../../domain/services/schedule_validator.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;
  final ScheduleEngine _scheduleEngine = const ScheduleEngine();
  final ScheduleValidator _scheduleValidator = const ScheduleValidator();
  final OfficialPerformancePreferenceResolver _performanceResolver =
      OfficialPerformancePreferenceResolver(
        repository: LocalPerformanceScheduleRepository(),
      );

  bool isLoading = false;
  String? errorMessage;

  DaySchedule? get schedule {
    return _appState.daySchedule;
  }

  String get selectedParkId {
    return _appState.tripSettings.parkId;
  }

  String get selectedParkName {
    return switch (selectedParkId) {
      'tokyo_disneyland' => '東京ディズニーランド',
      'tokyo_disneysea' => '東京ディズニーシー',
      _ => selectedParkId,
    };
  }

  IconData get selectedParkIcon {
    return switch (selectedParkId) {
      'tokyo_disneyland' => Icons.castle_outlined,
      'tokyo_disneysea' => Icons.water_outlined,
      _ => Icons.park_outlined,
    };
  }

  List<Facility> get selectedFacilitiesForCurrentPark {
    return List<Facility>.unmodifiable(
      _appState.selectedFacilities
          .where((facility) => facility.parkId == selectedParkId)
          .toList(growable: false),
    );
  }

  int get selectedFacilityCount {
    return selectedFacilitiesForCurrentPark.length;
  }

  List<Facility> get unavailableSelectedFacilities {
    return List<Facility>.unmodifiable(
      selectedFacilitiesForCurrentPark
          .where((facility) => !facility.isOpen)
          .toList(growable: false),
    );
  }

  int get unavailableSelectedFacilityCount {
    return unavailableSelectedFacilities.length;
  }

  bool get hasUnavailableSelectedFacilities {
    return unavailableSelectedFacilities.isNotEmpty;
  }

  bool get canGenerateSchedule {
    return selectedFacilitiesForCurrentPark.isNotEmpty;
  }

  bool get hasSchedule {
    return schedule != null;
  }

  bool get canUndo => _appState.canUndoScheduleChange;
  bool get canRedo => _appState.canRedoScheduleChange;
  int get historyCount => _appState.scheduleHistoryCount;

  List<ScheduleValidationIssue> get validationIssues {
    final current = schedule;
    if (current == null) {
      return const [];
    }
    return _scheduleValidator.validate(
      schedule: current,
      settings: _appState.tripSettings,
      preferences: _appState.planPreferences,
    );
  }

  void undoScheduleChange() => _appState.undoLastScheduleChange();
  void redoScheduleChange() => _appState.redoLastScheduleChange();

  bool get scheduleMatchesSelectedPark {
    final currentSchedule = schedule;

    if (currentSchedule == null) {
      return true;
    }

    return currentSchedule.parkId == selectedParkId;
  }

  bool get hasStaleSchedule {
    return schedule != null && !scheduleMatchesSelectedPark;
  }

  Facility? facilityById(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    for (final facility in _appState.selectedFacilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }

  PlanPreference? preferenceByFacilityId(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) {
      return null;
    }

    return _appState.getPreference(facilityId);
  }

  List<String> get fixedTimeConflicts {
    final byTime = <String, List<String>>{};
    for (final facility in selectedFacilitiesForCurrentPark) {
      final preference = _appState.getPreference(facility.id);
      if (preference == null ||
          preference.fixedTimeStatus != FixedTimeStatus.confirmed) {
        continue;
      }
      final time = preference.preferredPerformanceTime.trim().isNotEmpty
          ? preference.preferredPerformanceTime.trim()
          : preference.reservationTime.trim().isNotEmpty
          ? preference.reservationTime.trim()
          : preference.scheduledAccessTime.trim();
      if (time.isEmpty) continue;
      byTime.putIfAbsent(time, () => <String>[]).add(facility.name);
    }
    return [
      for (final entry in byTime.entries)
        if (entry.value.length > 1) '${entry.key}：${entry.value.join('、')}',
    ];
  }

  Future<void> generateSchedule() async {
    if (!canGenerateSchedule) {
      errorMessage =
          '現在のパークでは施設が選択されていません。'
          'プラン編集画面から行きたい施設を追加してください。';

      notifyListeners();

      return;
    }

    final conflicts = fixedTimeConflicts;
    if (conflicts.isNotEmpty) {
      errorMessage = '固定予定が競合しています。時刻を変更してください。\n${conflicts.join('\n')}';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final availableFacilities = selectedFacilitiesForCurrentPark
          .where((facility) => facility.isOpen)
          .toList(growable: false);

      if (availableFacilities.isEmpty) {
        errorMessage =
            '営業中の施設が選択されていません。'
            '休止中施設の選択を解除してください。';

        return;
      }

      final selectedFacilityIds = availableFacilities
          .map((facility) => facility.id)
          .toSet();

      final selectedPreferences = _appState.planPreferences
          .where((preference) {
            return selectedFacilityIds.contains(preference.facilityId);
          })
          .toList(growable: false);

      final settings = _appState.tripSettings;
      final preferences = await _performanceResolver.resolve(
        parkId: selectedParkId,
        date: DateTime.now(),
        entryMinutes: settings.entryTimeHour * 60 + settings.entryTimeMinute,
        exitMinutes: settings.exitTimeHour * 60 + settings.exitTimeMinute,
        facilities: availableFacilities,
        preferences: selectedPreferences,
      );

      for (final preference in preferences) {
        final current = _appState.getPreference(preference.facilityId);
        if (current == null ||
            current.preferredPerformanceTime ==
                preference.preferredPerformanceTime) {
          continue;
        }
        _appState.updatePreferenceSelectedPerformance(
          facilityId: preference.facilityId,
          performanceIndex: preference.selectedPerformanceIndex,
          startTime: preference.preferredPerformanceTime,
        );
      }

      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: selectedParkId);

      final generatedSchedule = _scheduleEngine.generate(
        settings: _appState.tripSettings,
        facilities: availableFacilities,
        preferences: preferences,
        eventImpacts: eventImpacts,
      );

      _appState.updateDaySchedule(generatedSchedule);
    } catch (error, stackTrace) {
      debugPrint('スケジュール生成に失敗しました: $error');

      debugPrintStack(stackTrace: stackTrace);

      errorMessage =
          'スケジュール生成に失敗しました。'
          '設定と選択施設を確認して、もう一度お試しください。';
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void clearSchedule() {
    errorMessage = null;

    _appState.clearDaySchedule();
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  void _onAppStateChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);

    super.dispose();
  }
}
