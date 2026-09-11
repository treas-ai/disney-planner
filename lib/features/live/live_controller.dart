import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../data/repositories/crowd_factor_repository_impl.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/services/schedule_engine.dart';
import 'live_data_controller.dart';
import 'live_models.dart';
import 'live_prediction_controller.dart';
import 'live_wait_time_controller.dart';

class LiveController extends ChangeNotifier {
  LiveController(
    this._appState, {
    LiveWaitTimeController? waitTimeController,
    LiveDataController? liveDataController,
    LivePredictionController? predictionController,
  }) : _waitTimeController = waitTimeController ?? LiveWaitTimeController(),
       _liveDataController = liveDataController ?? LiveDataController(),
       _predictionController =
           predictionController ?? LivePredictionController() {
    _appState.addListener(_onAppStateChanged);
    _waitTimeController.addListener(_onWaitTimeChanged);
    _liveDataController.addListener(_onLiveDataChanged);
    _predictionController.addListener(_onPredictionChanged);
  }

  final AppState _appState;
  final LiveWaitTimeController _waitTimeController;
  final LiveDataController _liveDataController;
  final LivePredictionController _predictionController;

  Timer? _clockTimer;

  DateTime _now = DateTime.now();

  bool _isInitialized = false;

  bool _simulationEnabled = false;
  DateTime? _simulationNow;
  DaySchedule? _simulationSchedule;
  final List<DaySchedule> _simulationUndoHistory = <DaySchedule>[];
  final Set<String> _simulationSuspendedFacilityIds = <String>{};
  final Map<String, int> _simulationWaitMinutesByFacilityId = <String, int>{};

  bool get simulationEnabled => _simulationEnabled;

  DateTime get now {
    return _simulationEnabled && _simulationNow != null
        ? _simulationNow!
        : _now;
  }

  DateTime? get visitDate => _appState.tripSettings.visitDate;

  LiveVisitPhase get visitPhase => resolveLiveVisitPhase(
    now: now,
    visitDate: visitDate,
  );

  bool get isVisitDay => visitPhase == LiveVisitPhase.visitDay;
  bool get canUseLiveOperations =>
      _simulationEnabled ||
      visitPhase == LiveVisitPhase.visitDay ||
      visitPhase == LiveVisitPhase.dateNotSet;

  Set<String> get suspendedFacilityIds => _simulationEnabled
      ? Set<String>.unmodifiable(_simulationSuspendedFacilityIds)
      : _appState.liveSuspendedFacilityIds;

  Map<String, int> get simulationWaitMinutesByFacilityId =>
      Map<String, int>.unmodifiable(_simulationWaitMinutesByFacilityId);

  bool get canUndoSimulationSchedule =>
      _simulationEnabled && _simulationUndoHistory.isNotEmpty;

  bool get isInitialized {
    return _isInitialized;
  }

  bool get isLoading {
    return _waitTimeController.isLoading ||
        _liveDataController.isLoading ||
        _predictionController.isLoading;
  }

  bool get isSaving {
    return _waitTimeController.isSaving;
  }

  String? get errorMessage {
    return _waitTimeController.errorMessage ??
        _liveDataController.errorMessage ??
        _predictionController.errorMessage;
  }

  LiveDataController get liveDataController {
    return _liveDataController;
  }

  LivePredictionController get predictionController {
    return _predictionController;
  }

  DateTime? get liveDataUpdatedAt {
    return _liveDataController.lastUpdatedAt;
  }

  LiveWaitTimeController get waitTimeController {
    return _waitTimeController;
  }

  DaySchedule? get schedule {
    return _simulationEnabled
        ? (_simulationSchedule ?? _appState.daySchedule)
        : _appState.daySchedule;
  }

  String get currentParkId {
    return _appState.tripSettings.parkId;
  }

  bool get scheduleMatchesCurrentPark {
    final currentSchedule = schedule;

    return currentSchedule == null || currentSchedule.parkId == currentParkId;
  }

  void startSimulation({required DateTime simulatedNow}) {
    _simulationEnabled = true;
    _simulationNow = simulatedNow;
    _simulationSchedule = _appState.daySchedule;
    _simulationUndoHistory.clear();
    _simulationSuspendedFacilityIds.clear();
    _simulationWaitMinutesByFacilityId.clear();
    _reloadPredictions();
    notifyListeners();
  }

  void stopSimulation() {
    if (!_simulationEnabled) return;
    _simulationEnabled = false;
    _simulationNow = null;
    _simulationSchedule = null;
    _simulationUndoHistory.clear();
    _simulationSuspendedFacilityIds.clear();
    _simulationWaitMinutesByFacilityId.clear();
    _reloadPredictions();
    notifyListeners();
  }

  void setSimulationTime(DateTime simulatedNow) {
    if (!_simulationEnabled) return;
    _simulationNow = simulatedNow;
    _reloadPredictions();
    notifyListeners();
  }

  int? simulationWaitMinutesForFacility(String? facilityId) {
    if (!_simulationEnabled || facilityId == null) return null;
    return _simulationWaitMinutesByFacilityId[facilityId];
  }

  void setSimulationWaitTime({
    required String facilityId,
    required int waitMinutes,
  }) {
    if (!_simulationEnabled) return;
    _simulationWaitMinutesByFacilityId[facilityId] = waitMinutes.clamp(0, 600).toInt();
    _reloadPredictions();
    notifyListeners();
  }

  void clearSimulationWaitTime(String facilityId) {
    if (!_simulationEnabled) return;
    if (_simulationWaitMinutesByFacilityId.remove(facilityId) != null) {
      _reloadPredictions();
      notifyListeners();
    }
  }

  bool isFacilitySuspended(String facilityId) {
    return _simulationEnabled
        ? _simulationSuspendedFacilityIds.contains(facilityId)
        : _appState.isFacilitySuspendedForToday(facilityId);
  }

  void suspendFacility(String facilityId) {
    if (_simulationEnabled) {
      if (_simulationSuspendedFacilityIds.add(facilityId)) {
        notifyListeners();
      }
      return;
    }
    _appState.suspendFacilityForToday(facilityId);
  }

  void resumeFacility(String facilityId) {
    if (_simulationEnabled) {
      if (_simulationSuspendedFacilityIds.remove(facilityId)) {
        notifyListeners();
      }
      return;
    }
    _appState.resumeFacilityForToday(facilityId);
  }

  LiveOperatingStatus? operatingStatusForFacility(String? facilityId) {
    if (facilityId == null || facilityId.trim().isEmpty) return null;
    if (_simulationEnabled) {
      if (_simulationSuspendedFacilityIds.contains(facilityId)) {
        return LiveOperatingStatus(
          parkId: currentParkId,
          facilityId: facilityId,
          state: LiveOperatingState.temporarilyClosed,
          updatedAt: now,
          message: 'シミュレーションで一時運営中止として設定',
        );
      }
      return null;
    }
    return _liveDataController.operatingStatusForFacility(facilityId);
  }

  void applySimulationSchedule(DaySchedule updatedSchedule) {
    if (!_simulationEnabled) return;
    final current = schedule;
    if (current != null) {
      _simulationUndoHistory.add(current);
      if (_simulationUndoHistory.length > 10) {
        _simulationUndoHistory.removeAt(0);
      }
    }
    _simulationSchedule = updatedSchedule;
    notifyListeners();
  }

  void undoSimulationSchedule() {
    if (!_simulationEnabled || _simulationUndoHistory.isEmpty) return;
    _simulationSchedule = _simulationUndoHistory.removeLast();
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    if (canUseLiveOperations) {
      await _waitTimeController.loadForPark(currentParkId);
      await _liveDataController.loadForPark(currentParkId);
    }
    await _reloadPredictions();

    _startClock();

    notifyListeners();
  }

  void refreshCurrentTime() {
    if (!_simulationEnabled) {
      _now = DateTime.now();
    }
    if (canUseLiveOperations) {
      _reloadPredictions();
    }
    notifyListeners();
  }

  Future<void> regenerateRemainingSchedule() async {
    if (!canUseLiveOperations) {
      return;
    }
    final currentSchedule = schedule;
    final currentNow = now;
    final nowMinutes = currentNow.hour * 60 + currentNow.minute;
    final currentItems = currentSchedule?.items ?? const <ScheduleItem>[];
    final preserved = currentItems
        .where((item) {
          final start = item.startHour * 60 + item.startMinute;
          return start <= nowMinutes;
        })
        .toList(growable: false);

    final facilities = _appState.selectedFacilities
        .where(
          (facility) => facility.parkId == currentParkId && facility.isOpen,
        )
        .toList(growable: false);
    final ids = facilities.map((facility) => facility.id).toSet();
    final preferences = _appState.planPreferences
        .where((preference) => ids.contains(preference.facilityId))
        .toList(growable: false);

    final generated = const ScheduleEngine().generate(
      settings: _appState.tripSettings,
      facilities: facilities,
      preferences: preferences,
    );
    final preservedIds = preserved.map((item) => item.id).toSet();
    final future = generated.items.where((item) {
      final start = item.startHour * 60 + item.startMinute;
      return start > nowMinutes && !preservedIds.contains(item.id);
    });
    final merged = <ScheduleItem>[...preserved, ...future]
      ..sort(
        (a, b) => (a.startHour * 60 + a.startMinute).compareTo(
          b.startHour * 60 + b.startMinute,
        ),
      );

    final updatedSchedule = DaySchedule(
      id: 'schedule_${DateTime.now().millisecondsSinceEpoch}',
      parkId: currentParkId,
      items: List<ScheduleItem>.unmodifiable(merged),
      createdAt: DateTime.now(),
    );
    if (_simulationEnabled) {
      applySimulationSchedule(updatedSchedule);
    } else {
      _appState.updateDaySchedule(updatedSchedule);
    }
  }

  Future<void> reloadWaitTimes() async {
    if (canUseLiveOperations && !_simulationEnabled) {
      await _waitTimeController.loadForPark(currentParkId);
      await _liveDataController.loadForPark(currentParkId);
    }
    await _reloadPredictions();
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

  LiveWaitTime? manualWaitTimeByFacilityId(String? facilityId) {
    return _waitTimeController.waitTimeForFacility(facilityId);
  }

  Future<bool> updateWaitTime({
    required Facility facility,
    required int waitMinutes,
  }) async {
    if (!canUseLiveOperations) return false;
    if (_simulationEnabled) {
      setSimulationWaitTime(
        facilityId: facility.id,
        waitMinutes: waitMinutes,
      );
      return true;
    }
    final saved = await _waitTimeController.updateWaitTime(
      facilityId: facility.id,
      parkId: facility.parkId,
      waitMinutes: waitMinutes,
    );
    if (saved) {
      await _reloadPredictions();
    }
    return saved;
  }

  Future<bool> clearWaitTime(Facility facility) async {
    if (!canUseLiveOperations) return false;
    if (_simulationEnabled) {
      clearSimulationWaitTime(facility.id);
      return true;
    }
    final removed = await _waitTimeController.removeWaitTime(facility.id);
    if (removed) {
      await _reloadPredictions();
    }
    return removed;
  }

  void clearError() {
    _waitTimeController.clearError();
  }

  LiveScheduleSnapshot buildSnapshot() {
    final currentSchedule = schedule;
    final phase = visitPhase;
    final targetDate = visitDate;

    if (currentSchedule == null || currentSchedule.items.isEmpty) {
      return LiveScheduleSnapshot(
        now: now,
        status: LiveScheduleStatus.noSchedule,
        completedItemCount: 0,
        totalItemCount: 0,
        visitPhase: phase,
        visitDate: targetDate,
      );
    }

    if (currentSchedule.parkId != currentParkId) {
      return LiveScheduleSnapshot(
        now: now,
        status: LiveScheduleStatus.parkMismatch,
        completedItemCount: 0,
        totalItemCount: currentSchedule.items.length,
        visitPhase: phase,
        visitDate: targetDate,
      );
    }

    final sortedItems = List<ScheduleItem>.of(currentSchedule.items)
      ..sort((left, right) {
        return _startMinutes(left).compareTo(_startMinutes(right));
      });

    if (phase == LiveVisitPhase.preVisit) {
      final nextItem = sortedItems.first;
      final followingItem = sortedItems.length > 1 ? sortedItems[1] : null;
      final nextFacility = facilityById(nextItem.facilityId);
      final nextPreference = preferenceByFacilityId(nextItem.facilityId);
      final nextWaitTime = _resolveWaitTimeDisplay(
        facility: nextFacility,
        preference: nextPreference,
        plannedWaitMinutes: nextItem.estimatedWaitMinutes,
        plannedWaitSource: nextItem.waitEstimateSource,
      );
      final nextExpectedEndAt = _calculateExpectedEndAt(
        item: nextItem,
        facility: nextFacility,
        waitTime: nextWaitTime,
      );
      return LiveScheduleSnapshot(
        now: now,
        status: LiveScheduleStatus.beforeParkOpen,
        completedItemCount: 0,
        totalItemCount: sortedItems.length,
        visitPhase: phase,
        visitDate: targetDate,
        nextItem: nextItem,
        followingItem: followingItem,
        nextFacility: nextFacility,
        nextPreference: nextPreference,
        nextWaitTime: nextWaitTime,
        nextExpectedEndAt: nextExpectedEndAt,
        canCompleteNextBeforeFollowingItem: true,
      );
    }

    if (phase == LiveVisitPhase.postVisit) {
      return LiveScheduleSnapshot(
        now: now,
        status: LiveScheduleStatus.pastVisit,
        completedItemCount: 0,
        totalItemCount: sortedItems.length,
        visitPhase: phase,
        visitDate: targetDate,
      );
    }

    final currentNow = now;
    final currentMinutes = currentNow.hour * 60 + currentNow.minute;
    ScheduleItem? currentItem;
    ScheduleItem? nextItem;
    ScheduleItem? followingItem;
    var completedCount = 0;

    for (var index = 0; index < sortedItems.length; index++) {
      final item = sortedItems[index];
      final startMinutes = _startMinutes(item);
      final endMinutes = _endMinutes(item);

      if (currentMinutes >= endMinutes) {
        completedCount++;
        continue;
      }

      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        currentItem = item;
        if (index + 1 < sortedItems.length) nextItem = sortedItems[index + 1];
        if (index + 2 < sortedItems.length) followingItem = sortedItems[index + 2];
        break;
      }

      if (currentMinutes < startMinutes) {
        nextItem = item;
        if (index + 1 < sortedItems.length) followingItem = sortedItems[index + 1];
        break;
      }
    }

    if (currentItem == null && nextItem == null) {
      return LiveScheduleSnapshot(
        now: now,
        status: LiveScheduleStatus.completed,
        completedItemCount: sortedItems.length,
        totalItemCount: sortedItems.length,
        visitPhase: phase,
        visitDate: targetDate,
      );
    }

    final currentFacility = facilityById(currentItem?.facilityId);
    final nextFacility = facilityById(nextItem?.facilityId);
    final currentPreference = preferenceByFacilityId(currentItem?.facilityId);
    final nextPreference = preferenceByFacilityId(nextItem?.facilityId);
    final currentWaitTime = _resolveWaitTimeDisplay(
      facility: currentFacility,
      preference: currentPreference,
      plannedWaitMinutes: currentItem?.estimatedWaitMinutes,
      plannedWaitSource: currentItem?.waitEstimateSource,
    );
    final nextWaitTime = _resolveWaitTimeDisplay(
      facility: nextFacility,
      preference: nextPreference,
      plannedWaitMinutes: nextItem?.estimatedWaitMinutes,
      plannedWaitSource: nextItem?.waitEstimateSource,
    );
    final minutesUntilNext = nextItem == null
        ? null
        : _startMinutes(nextItem) - currentMinutes;
    final currentRemainingMinutes = currentItem == null
        ? null
        : _endMinutes(currentItem) - currentMinutes;
    final freeTimeMinutes =
        currentItem == null &&
            nextItem != null &&
            minutesUntilNext != null &&
            minutesUntilNext > 0
        ? minutesUntilNext
        : null;
    final nextExpectedEndAt = _calculateExpectedEndAt(
      item: nextItem,
      facility: nextFacility,
      waitTime: nextWaitTime,
    );
    final canCompleteBeforeFollowing = _canCompleteBeforeFollowingItem(
      expectedEndAt: nextExpectedEndAt,
      followingItem: followingItem,
    );
    final status = currentItem != null
        ? LiveScheduleStatus.current
        : freeTimeMinutes != null
        ? LiveScheduleStatus.freeTime
        : LiveScheduleStatus.upcoming;

    return LiveScheduleSnapshot(
      now: now,
      status: status,
      completedItemCount: completedCount,
      totalItemCount: sortedItems.length,
      visitPhase: phase,
      visitDate: targetDate,
      currentItem: currentItem,
      nextItem: nextItem,
      followingItem: followingItem,
      currentFacility: currentFacility,
      nextFacility: nextFacility,
      currentPreference: currentPreference,
      nextPreference: nextPreference,
      currentWaitTime: currentWaitTime,
      nextWaitTime: nextWaitTime,
      minutesUntilNext: minutesUntilNext,
      currentRemainingMinutes: currentRemainingMinutes,
      freeTimeMinutes: freeTimeMinutes,
      nextExpectedEndAt: nextExpectedEndAt,
      canCompleteNextBeforeFollowingItem: canCompleteBeforeFollowing,
    );
  }

  int? currentOrNextIndex() {
    final currentSchedule = schedule;

    if (currentSchedule == null || currentSchedule.items.isEmpty) {
      return null;
    }

    if (visitPhase == LiveVisitPhase.preVisit ||
        visitPhase == LiveVisitPhase.postVisit) {
      return 0;
    }

    final currentNow = now;
    final currentMinutes = currentNow.hour * 60 + currentNow.minute;

    for (var index = 0; index < currentSchedule.items.length; index++) {
      final item = currentSchedule.items[index];

      if (currentMinutes < _endMinutes(item)) {
        return index;
      }
    }

    return currentSchedule.items.length - 1;
  }

  LiveWaitTimeDisplay? _resolveWaitTimeDisplay({
    required Facility? facility,
    required PlanPreference? preference,
    int? plannedWaitMinutes,
    String? plannedWaitSource,
  }) {
    if (facility == null ||
        (facility.category != FacilityCategory.attraction &&
            facility.category != FacilityCategory.greeting)) {
      return null;
    }

    final normalizedPlannedSource = plannedWaitSource?.trim() ?? '';
    final usesUnlimitedRideBuffer =
        normalizedPlannedSource.startsWith('バケーションパッケージ乗り放題') ||
        normalizedPlannedSource.startsWith('バケパ乗り放題');
    if (usesUnlimitedRideBuffer && plannedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.passEstimate,
        label: 'バケパ乗り放題・優先入口利用バッファ',
        waitMinutes: plannedWaitMinutes,
        isStale: false,
      );
    }

    final accessMethod =
        preference?.accessMethod ?? FacilityAccessMethod.standby;

    final passEstimate = _passWaitEstimate(
      facility: facility,
      accessMethod: accessMethod,
    );

    if (passEstimate != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.passEstimate,
        label: '${accessMethod.liveShortLabel}・優先利用バッファ',
        waitMinutes: passEstimate,
        isStale: false,
      );
    }

    final simulatedWaitMinutes = simulationWaitMinutesForFacility(facility.id);
    if (simulatedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: 'シミュレーション・仮想通常待機',
        waitMinutes: simulatedWaitMinutes,
        isStale: false,
      );
    }

    final manualWaitTime = canUseLiveOperations
        ? manualWaitTimeByFacilityId(facility.id)
        : null;

    if (manualWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: '手動入力',
        waitMinutes: manualWaitTime.waitMinutes,
        isStale: manualWaitTime.isStaleAt(now),
        updatedAt: manualWaitTime.updatedAt,
      );
    }

    final facilityWaitMinutes = canUseLiveOperations
        ? facility.waitTime?.minutes
        : null;

    if (facilityWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: '施設データの目安',
        waitMinutes: facilityWaitMinutes,
        isStale: false,
      );
    }

    if (plannedWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: facility.category == FacilityCategory.greeting
            ? 'グリーティング計画値'
            : 'プラン作成時の計画値',
        waitMinutes: plannedWaitMinutes,
        isStale: false,
      );
    }

    return const LiveWaitTimeDisplay(
      kind: LiveWaitTimeKind.unknown,
      label: '待ち時間不明',
      waitMinutes: null,
      isStale: false,
    );
  }

  int? _passWaitEstimate({
    required Facility facility,
    required FacilityAccessMethod accessMethod,
  }) {
    return switch (accessMethod) {
      FacilityAccessMethod.dpa => facility.supportsDpa ? 10 : null,
      FacilityAccessMethod.priorityPass =>
        facility.supportsPriorityPass ? 15 : null,
      FacilityAccessMethod.standbyPass =>
        facility.supportsStandbyPass ? 20 : null,
      FacilityAccessMethod.entryRequest =>
        facility.requiresEntryRequest ? 15 : null,
      FacilityAccessMethod.reservation => 10,
      FacilityAccessMethod.freeSeating => null,
      FacilityAccessMethod.standby => null,
    };
  }

  DateTime? _calculateExpectedEndAt({
    required ScheduleItem? item,
    required Facility? facility,
    required LiveWaitTimeDisplay? waitTime,
  }) {
    if (item == null) {
      return null;
    }

    final planDate = _planCalendarDate;
    final startAt = DateTime(
      planDate.year,
      planDate.month,
      planDate.day,
      item.startHour,
      item.startMinute,
    );

    if (facility == null ||
        (facility.category != FacilityCategory.attraction &&
            facility.category != FacilityCategory.greeting)) {
      return DateTime(
        planDate.year,
        planDate.month,
        planDate.day,
        item.endHour,
        item.endMinute,
      );
    }

    final waitMinutes = waitTime?.waitMinutes ?? 0;

    final durationMinutes = facility.durationMinutes > 0
        ? facility.durationMinutes
        : _scheduledDurationMinutes(item);

    return startAt.add(Duration(minutes: waitMinutes + durationMinutes));
  }

  bool _canCompleteBeforeFollowingItem({
    required DateTime? expectedEndAt,
    required ScheduleItem? followingItem,
  }) {
    if (expectedEndAt == null || followingItem == null) {
      return true;
    }

    final planDate = _planCalendarDate;
    final followingStartAt = DateTime(
      planDate.year,
      planDate.month,
      planDate.day,
      followingItem.startHour,
      followingItem.startMinute,
    );

    return !expectedEndAt.isAfter(followingStartAt);
  }

  DateTime get _planCalendarDate {
    final target = visitDate;
    return target == null
        ? DateTime(now.year, now.month, now.day)
        : DateTime(target.year, target.month, target.day);
  }

  int _scheduledDurationMinutes(ScheduleItem item) {
    final duration = _endMinutes(item) - _startMinutes(item);

    return duration < 0 ? 0 : duration;
  }

  int _startMinutes(ScheduleItem item) {
    return item.startHour * 60 + item.startMinute;
  }

  int _endMinutes(ScheduleItem item) {
    return item.endHour * 60 + item.endMinute;
  }

  void _startClock() {
    _clockTimer?.cancel();

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _now = DateTime.now();

      notifyListeners();
    });
  }

  void _onAppStateChanged() {
    if (_isInitialized) {
      if (canUseLiveOperations && !_simulationEnabled) {
        final loadedParkIds = _waitTimeController.waitTimes
            .map((waitTime) => waitTime.parkId)
            .toSet();
        if (!loadedParkIds.contains(currentParkId)) {
          _waitTimeController.loadForPark(currentParkId);
          _liveDataController.loadForPark(currentParkId);
        }
      }
      _reloadPredictions();
    }

    notifyListeners();
  }

  void _onWaitTimeChanged() {
    notifyListeners();
  }

  void _onLiveDataChanged() {
    notifyListeners();
  }

  void _onPredictionChanged() {
    notifyListeners();
  }

  Future<void> _reloadPredictions() async {
    final waitFacilities = _appState.selectedFacilities.where(
      (facility) =>
          facility.parkId == currentParkId &&
          (facility.category == FacilityCategory.attraction ||
              facility.category == FacilityCategory.greeting),
    );
    final targetDate = _planCalendarDate;
    final phase = visitPhase;
    final useLiveTargets = phase == LiveVisitPhase.visitDay ||
        phase == LiveVisitPhase.dateNotSet;
    final referenceTime = useLiveTargets
        ? now
        : DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            _appState.tripSettings.entryTimeHour,
            _appState.tripSettings.entryTimeMinute,
          );

    final waitProfiles = await const CrowdFactorRepositoryImpl()
        .loadWaitProfiles(parkId: currentParkId);
    final plannedTargetByFacilityId = <String, DateTime>{};
    final plannedWaitByFacilityId = <String, int>{};
    final plannedSourceByFacilityId = <String, String>{};
    final currentSchedule = schedule;
    if (currentSchedule != null && currentSchedule.parkId == currentParkId) {
      for (final item in currentSchedule.items) {
        final facilityId = item.facilityId;
        if (facilityId == null) continue;
        plannedTargetByFacilityId.putIfAbsent(
          facilityId,
          () => DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            item.startHour,
            item.startMinute,
          ),
        );
        final plannedWait = item.estimatedWaitMinutes;
        if (plannedWait != null) {
          plannedWaitByFacilityId.putIfAbsent(facilityId, () => plannedWait);
        }
        final source = item.waitEstimateSource?.trim();
        if (source != null && source.isNotEmpty) {
          plannedSourceByFacilityId.putIfAbsent(facilityId, () => source);
        }
      }
    }

    return _predictionController.load(
      parkId: currentParkId,
      facilities: waitFacilities,
      referenceTime: referenceTime,
      useVisitDayTargets: useLiveTargets,
      waitProfiles: waitProfiles,
      currentWaitTimeFor: (facilityId) {
        if (!useLiveTargets) return null;
        return _waitTimeController.waitTimeForFacility(facilityId) ??
            _liveDataController.waitTimeForFacility(facilityId);
      },
      plannedTargetTimeFor: (facilityId) =>
          plannedTargetByFacilityId[facilityId],
      planningFallbackMinutesFor: (facilityId) {
        final facility = facilityById(facilityId);
        if (facility?.category != FacilityCategory.greeting) return null;
        return plannedWaitByFacilityId[facilityId];
      },
      planningFallbackReasonFor: (facilityId) {
        final facility = facilityById(facilityId);
        if (facility?.category != FacilityCategory.greeting) return null;
        final source = plannedSourceByFacilityId[facilityId];
        if (source == null || source.isEmpty) {
          return 'グリーティングは実測収集対象外のため、混雑補正済みのDisney Planner計画値を使用しました。';
        }
        return '$source。';
      },
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel();

    _appState.removeListener(_onAppStateChanged);

    _waitTimeController.removeListener(_onWaitTimeChanged);
    _liveDataController.removeListener(_onLiveDataChanged);
    _predictionController.removeListener(_onPredictionChanged);

    _waitTimeController.dispose();
    _liveDataController.dispose();
    _predictionController.dispose();

    super.dispose();
  }
}
