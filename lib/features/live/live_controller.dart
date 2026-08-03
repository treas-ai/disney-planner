import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/entities/plan_preference.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/facility_category.dart';
import 'live_models.dart';
import 'live_wait_time_controller.dart';

class LiveController extends ChangeNotifier {
  LiveController(this._appState, {LiveWaitTimeController? waitTimeController})
    : _waitTimeController = waitTimeController ?? LiveWaitTimeController() {
    _appState.addListener(_onAppStateChanged);

    _waitTimeController.addListener(_onWaitTimeChanged);
  }

  final AppState _appState;
  final LiveWaitTimeController _waitTimeController;

  Timer? _clockTimer;

  DateTime _now = DateTime.now();

  bool _isInitialized = false;

  DateTime get now {
    return _now;
  }

  bool get isInitialized {
    return _isInitialized;
  }

  bool get isLoading {
    return _waitTimeController.isLoading;
  }

  bool get isSaving {
    return _waitTimeController.isSaving;
  }

  String? get errorMessage {
    return _waitTimeController.errorMessage;
  }

  LiveWaitTimeController get waitTimeController {
    return _waitTimeController;
  }

  DaySchedule? get schedule {
    return _appState.daySchedule;
  }

  String get currentParkId {
    return _appState.tripSettings.parkId;
  }

  bool get scheduleMatchesCurrentPark {
    final currentSchedule = schedule;

    return currentSchedule == null || currentSchedule.parkId == currentParkId;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    await _waitTimeController.loadForPark(currentParkId);

    _startClock();

    notifyListeners();
  }

  void refreshCurrentTime() {
    _now = DateTime.now();

    notifyListeners();
  }

  Future<void> reloadWaitTimes() async {
    await _waitTimeController.loadForPark(currentParkId);
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
  }) {
    return _waitTimeController.updateWaitTime(
      facilityId: facility.id,
      parkId: facility.parkId,
      waitMinutes: waitMinutes,
    );
  }

  Future<bool> clearWaitTime(Facility facility) {
    return _waitTimeController.removeWaitTime(facility.id);
  }

  void clearError() {
    _waitTimeController.clearError();
  }

  LiveScheduleSnapshot buildSnapshot() {
    final currentSchedule = schedule;

    if (currentSchedule == null || currentSchedule.items.isEmpty) {
      return LiveScheduleSnapshot(
        now: _now,
        status: LiveScheduleStatus.noSchedule,
        completedItemCount: 0,
        totalItemCount: 0,
      );
    }

    if (currentSchedule.parkId != currentParkId) {
      return LiveScheduleSnapshot(
        now: _now,
        status: LiveScheduleStatus.parkMismatch,
        completedItemCount: 0,
        totalItemCount: currentSchedule.items.length,
      );
    }

    final sortedItems = List<ScheduleItem>.of(currentSchedule.items)
      ..sort((left, right) {
        return _startMinutes(left).compareTo(_startMinutes(right));
      });

    final currentMinutes = _now.hour * 60 + _now.minute;

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

        if (index + 1 < sortedItems.length) {
          nextItem = sortedItems[index + 1];
        }

        if (index + 2 < sortedItems.length) {
          followingItem = sortedItems[index + 2];
        }

        break;
      }

      if (currentMinutes < startMinutes) {
        nextItem = item;

        if (index + 1 < sortedItems.length) {
          followingItem = sortedItems[index + 1];
        }

        break;
      }
    }

    if (currentItem == null && nextItem == null) {
      return LiveScheduleSnapshot(
        now: _now,
        status: LiveScheduleStatus.completed,
        completedItemCount: sortedItems.length,
        totalItemCount: sortedItems.length,
      );
    }

    final currentFacility = facilityById(currentItem?.facilityId);

    final nextFacility = facilityById(nextItem?.facilityId);

    final currentPreference = preferenceByFacilityId(currentItem?.facilityId);

    final nextPreference = preferenceByFacilityId(nextItem?.facilityId);

    final currentWaitTime = _resolveWaitTimeDisplay(
      facility: currentFacility,
      preference: currentPreference,
    );

    final nextWaitTime = _resolveWaitTimeDisplay(
      facility: nextFacility,
      preference: nextPreference,
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
      now: _now,
      status: status,
      completedItemCount: completedCount,
      totalItemCount: sortedItems.length,
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

    final currentMinutes = _now.hour * 60 + _now.minute;

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
  }) {
    if (facility == null || facility.category != FacilityCategory.attraction) {
      return null;
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
        label: '${accessMethod.liveShortLabel}利用時の目安',
        waitMinutes: passEstimate,
        isStale: false,
      );
    }

    final manualWaitTime = manualWaitTimeByFacilityId(facility.id);

    if (manualWaitTime != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.manual,
        label: '手動入力',
        waitMinutes: manualWaitTime.waitMinutes,
        isStale: manualWaitTime.isStaleAt(_now),
        updatedAt: manualWaitTime.updatedAt,
      );
    }

    final facilityWaitMinutes = facility.waitTime?.minutes;

    if (facilityWaitMinutes != null) {
      return LiveWaitTimeDisplay(
        kind: LiveWaitTimeKind.facilityEstimate,
        label: '施設データの目安',
        waitMinutes: facilityWaitMinutes,
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

    final startAt = DateTime(
      _now.year,
      _now.month,
      _now.day,
      item.startHour,
      item.startMinute,
    );

    if (facility == null || facility.category != FacilityCategory.attraction) {
      return DateTime(
        _now.year,
        _now.month,
        _now.day,
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

    final followingStartAt = DateTime(
      _now.year,
      _now.month,
      _now.day,
      followingItem.startHour,
      followingItem.startMinute,
    );

    return !expectedEndAt.isAfter(followingStartAt);
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
    final loadedParkIds = _waitTimeController.waitTimes
        .map((waitTime) => waitTime.parkId)
        .toSet();

    if (_isInitialized && !loadedParkIds.contains(currentParkId)) {
      _waitTimeController.loadForPark(currentParkId);
    }

    notifyListeners();
  }

  void _onWaitTimeChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();

    _appState.removeListener(_onAppStateChanged);

    _waitTimeController.removeListener(_onWaitTimeChanged);

    _waitTimeController.dispose();

    super.dispose();
  }
}
