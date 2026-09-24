import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../core/debug/debug_verification_report.dart';
import '../../core/debug/debug_gate_registry.dart';
import '../../data/repositories/crowd_factor_repository_impl.dart';
import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/schedule_recalculation_request.dart';
import '../../domain/entities/schedule_recalculation_result.dart';
import '../../domain/entities/weather_snapshot.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/entities/schedule_item.dart';
import '../../domain/enums/schedule_item_type.dart';
import '../../domain/enums/facility_access_method.dart';
import '../../domain/enums/today_access_kind.dart';
import '../../domain/enums/today_access_status.dart';
import '../../domain/enums/live_weather_condition.dart';
import '../../domain/services/schedule_recalculation_service.dart';
import '../live/live_controller.dart';

class ScheduleRecalculationController extends ChangeNotifier {
  ScheduleRecalculationController(
    this._appState,
    this._liveController, [
    this._service = const ScheduleRecalculationService(),
  ]);

  final AppState _appState;
  final LiveController _liveController;
  final ScheduleRecalculationService _service;

  bool _isCalculating = false;
  String? _errorMessage;
  ScheduleRecalculationResult? _pendingResult;
  DaySchedule? _lastBeforeSchedule;
  DaySchedule? _lastAfterSchedule;
  List<ScheduleItem> _lastPreservedItems = const [];
  int? _lastBreakDurationMinutes;
  String _lastVerificationAction = 'recalculate';
  String? _lastVerificationDetail;
  bool? _lastUndoRestored;
  bool _lastUndoAvailableAfterApply = false;
  String? _verificationReport;
  String? _currentFacilityId;

  bool get isCalculating => _isCalculating;
  String? get errorMessage => _errorMessage;
  ScheduleRecalculationResult? get pendingResult => _pendingResult;
  String? get verificationReport => _verificationReport;
  bool get canApply => _pendingResult != null;
  bool get canUndo => _liveController.simulationEnabled
      ? _liveController.canUndoSimulationSchedule
      : _appState.canUndoScheduleChange;
  Set<String> get suspendedFacilityIds => _liveController.suspendedFacilityIds;
  String? get currentFacilityId => _currentFacilityId;

  void setCurrentFacility(String? facilityId) {
    if (_currentFacilityId == facilityId) return;
    _currentFacilityId = facilityId;
    notifyListeners();
  }

  bool isSuspended(String facilityId) {
    return _liveController.isFacilitySuspended(facilityId);
  }

  void suspendFacility(String facilityId) {
    _liveController.suspendFacility(facilityId);
  }

  void resumeFacility(String facilityId) {
    _liveController.resumeFacility(facilityId);
  }

  Future<ScheduleRecalculationResult?> createProposal({
    int? breakDurationMinutes,
    String verificationAction = 'recalculate',
    String? verificationDetail,
  }) async {
    final schedule = _liveController.schedule;
    if (schedule == null) {
      _errorMessage = '再計算するスケジュールがありません。';
      notifyListeners();
      return null;
    }

    _isCalculating = true;
    _errorMessage = null;
    _lastBreakDurationMinutes = breakDurationMinutes;
    _lastVerificationAction = breakDurationMinutes != null
        ? 'break'
        : verificationAction;
    _lastVerificationDetail = verificationDetail;
    notifyListeners();
    try {
      final waitTimes = <String, dynamic>{};
      final operating = <String, dynamic>{};
      for (final facility in _appState.selectedFacilities) {
        final wait =
            _liveController.liveDataController.waitTimeForFacility(
              facility.id,
            ) ??
            _liveController.manualWaitTimeByFacilityId(facility.id);
        if (wait != null) waitTimes[facility.id] = wait;
        final status = _liveController.operatingStatusForFacility(facility.id);
        if (status != null) operating[facility.id] = status;
      }

      for (final facilityId in _liveController.suspendedFacilityIds) {
        operating[facilityId] = LiveOperatingStatus(
          parkId: schedule.parkId,
          facilityId: facilityId,
          state: LiveOperatingState.temporarilyClosed,
          updatedAt: _liveController.now,
          message: 'ユーザーが当日ガイドで一時運営中止として設定',
        );
      }

      final waitProfiles = await const CrowdFactorRepositoryImpl()
          .loadWaitProfilesForDate(
            parkId: schedule.parkId,
            targetDate: _appState.tripSettings.visitDate ?? _liveController.now,
          );

      _pendingResult = _service.createProposal(
        ScheduleRecalculationRequest(
          now: _liveController.now,
          currentSchedule: schedule,
          settings: _appState.tripSettings,
          facilities: _appState.selectedFacilitiesForPark(schedule.parkId),
          preferences: _appState.effectivePlanPreferencesForToday,
          waitTimes: waitTimes.cast(),
          operatingStatuses: operating.cast(),
          weather: _appState.tripSettings.isRainy
              ? WeatherSnapshot(
                  condition: LiveWeatherCondition.rain,
                  updatedAt: _liveController.now,
                )
              : null,
          passStatuses: _liveController.liveDataController.passStatuses,
          waitProfiles: waitProfiles,
          releasedFacilityIds: _appState.releasedFacilityIdsForToday,
          todayAccessResults: _appState.todayAccessResults,
          executedFacilityIds: _liveController.executionExcludedFacilityIds,
          todayExecutionRecords: _liveController.executionRecords,
          currentFacilityId: _currentFacilityId,
          breakDurationMinutes: breakDurationMinutes,
        ),
        simulatedWaitMinutesByFacilityId:
            _liveController.simulationWaitMinutesByFacilityId,
      );
      return _pendingResult;
    } catch (error, stackTrace) {
      debugPrint('スケジュール再計算に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'スケジュールの再計算に失敗しました。';
      return null;
    } finally {
      _isCalculating = false;
      notifyListeners();
    }
  }

  void applyProposal() {
    final result = _pendingResult;
    if (result == null) return;
    _lastBeforeSchedule = result.beforeSchedule;
    _lastAfterSchedule = result.afterSchedule;
    _lastPreservedItems = List<ScheduleItem>.unmodifiable(result.preservedItems);
    _lastUndoRestored = null;
    if (_liveController.simulationEnabled) {
      _liveController.applySimulationSchedule(result.afterSchedule);
    } else {
      _appState.applyRecalculatedSchedule(result.afterSchedule);
    }
    _lastUndoAvailableAfterApply = canUndo;
    _verificationReport = _buildVerificationReport(undoRestored: null);
    DebugGateRegistry.lastTodayReplanReport = _verificationReport;
    _pendingResult = null;
    notifyListeners();
  }

  void discardProposal() {
    _pendingResult = null;
    notifyListeners();
  }

  void undoLastApply() {
    if (_liveController.simulationEnabled) {
      _liveController.undoSimulationSchedule();
    } else {
      _appState.undoLastScheduleChange();
    }
    final restored = _liveController.schedule;
    _lastUndoRestored = _sameSchedule(restored, _lastBeforeSchedule);
    _verificationReport = _buildVerificationReport(
      undoRestored: _lastUndoRestored,
    );
    DebugGateRegistry.lastTodayReplanReport = _verificationReport;
    notifyListeners();
  }

  String _buildVerificationReport({required bool? undoRestored}) {
    final before = _lastBeforeSchedule;
    final after = _lastAfterSchedule;
    if (before == null || after == null) return 'No verification data.';

    final requestedBreakMinutes = _lastBreakDurationMinutes;
    final isBreakAction = requestedBreakMinutes != null;
    final addedBreakItems = after.items.where((item) {
      return item.type == ScheduleItemType.breakTime &&
          item.id.startsWith('today_break_');
    }).toList(growable: false);
    final matchingBreakItems = addedBreakItems.where((item) {
      final duration = _itemDurationMinutes(item);
      final start = item.startHour * 60 + item.startMinute;
      final now = _liveController.now.hour * 60 + _liveController.now.minute;
      return duration == requestedBreakMinutes && start >= now;
    }).toList(growable: false);

    final overlapDetails = _overlapDetails(after);
    final overlaps = overlapDetails.length;
    final beforeExit = _exitText(before);
    final afterExit = _exitText(after);
    final exitMaintained = beforeExit == afterExit;
    final preservedMaintained = _lastPreservedItemsMaintained(after);
    final breakValid = !isBreakAction || matchingBreakItems.length == 1;
    final undoWasRun = undoRestored != null;
    final undoOk = undoRestored == true;
    final isAcquiredDpaAction = _lastVerificationAction == 'acquired-dpa';
    final acquiredDpaWithTime = _appState.todayAccessResults.where((result) =>
        result.kind == TodayAccessKind.attractionDpa &&
        result.status == TodayAccessStatus.acquired &&
        result.fixesTime).toList(growable: false);
    final dpaMismatches = <String>[];
    for (final result in acquiredDpaWithTime) {
      final matched = after.items.any((item) =>
          item.facilityId == result.facilityId &&
          item.accessMethod == FacilityAccessMethod.dpa &&
          item.startTimeLabel == result.time);
      if (!matched) {
        dpaMismatches.add('${result.facilityId} acquired=${result.time}');
      }
    }
    final acquiredDpaAuthoritative =
        acquiredDpaWithTime.isNotEmpty && dpaMismatches.isEmpty;
    final acquiredDpaFacilityIds = acquiredDpaWithTime
        .map((result) => result.facilityId)
        .toSet();
    final acquiredDpaConflictDetails = _overlapDetails(
      after,
      requiredFacilityIds: acquiredDpaFacilityIds,
    );

    final lines = <String>[
      if (_lastVerificationDetail != null)
        'Detail: $_lastVerificationDetail',
      'Requested: ${requestedBreakMinutes == null ? '-' : '$requestedBreakMinutes min'}',
      'Now: ${_timeText(_liveController.now.hour, _liveController.now.minute)}',
      'Before items: ${before.items.length}',
      'After items: ${after.items.length}',
      'Before exit: $beforeExit',
      'After exit: $afterExit',
      'Added break blocks: ${addedBreakItems.length}',
      'Overlaps after: $overlaps',
      if (overlapDetails.isNotEmpty)
        ...overlapDetails.map((detail) => 'Overlap detail: $detail'),
      if (isAcquiredDpaAction)
        'Acquired DPA fixed times: ${acquiredDpaWithTime.isEmpty ? 'NONE' : acquiredDpaWithTime.map((result) => '${result.facilityId}=${result.time}').join(', ')}',
      if (isAcquiredDpaAction)
        'Scheduled acquired DPA matches: ${dpaMismatches.isEmpty && acquiredDpaWithTime.isNotEmpty ? 'YES' : 'NO'}',
      if (isAcquiredDpaAction)
        'Acquired DPA conflicts after: ${acquiredDpaConflictDetails.length}',
      if (isAcquiredDpaAction && acquiredDpaConflictDetails.isNotEmpty)
        ...acquiredDpaConflictDetails
            .map((detail) => 'Acquired DPA conflict detail: $detail'),
    ];
    if (matchingBreakItems.length == 1) {
      final item = matchingBreakItems.single;
      lines.add(
        'Break: ${_timeText(item.startHour, item.startMinute)}-'
        '${_timeText(item.endHour, item.endMinute)}',
      );
    } else if (isBreakAction) {
      lines.add('Break: NOT_FOUND_OR_AMBIGUOUS');
    }
    lines.add('Undo restored: ${!undoWasRun ? 'NOT_RUN' : undoOk ? 'YES' : 'NO'}');

    final report = DebugVerificationReport(
      feature: 'Today Replan',
      action: _lastVerificationAction,
      lines: lines,
      gates: [
        DebugVerificationGate(
          name: 'Exit maintained',
          status: exitMaintained
              ? DebugVerificationGateStatus.pass
              : DebugVerificationGateStatus.check,
        ),
        DebugVerificationGate(
          name: 'Protected items maintained',
          status: preservedMaintained
              ? DebugVerificationGateStatus.pass
              : DebugVerificationGateStatus.check,
        ),
        if (isBreakAction)
          DebugVerificationGate(
            name: 'Requested break valid',
            status: breakValid
                ? DebugVerificationGateStatus.pass
                : DebugVerificationGateStatus.check,
          ),
        if (isAcquiredDpaAction)
          DebugVerificationGate(
            name: 'Acquired DPA fixed time maintained',
            status: acquiredDpaAuthoritative
                ? DebugVerificationGateStatus.pass
                : DebugVerificationGateStatus.check,
            detail: acquiredDpaWithTime.isEmpty
                ? 'no acquired DPA with fixed time found'
                : dpaMismatches.isEmpty
                    ? acquiredDpaWithTime
                        .map((result) => '${result.facilityId} ${result.time}')
                        .join(' / ')
                    : dpaMismatches.join(' / '),
          ),
        if (isAcquiredDpaAction)
          DebugVerificationGate(
            name: 'No conflicts with acquired DPA after',
            status: acquiredDpaConflictDetails.isEmpty
                ? DebugVerificationGateStatus.pass
                : DebugVerificationGateStatus.check,
            detail: '${acquiredDpaConflictDetails.length} conflict(s)',
          ),
        DebugVerificationGate(
          name: 'No overlaps after',
          status: overlaps == 0
              ? DebugVerificationGateStatus.pass
              : DebugVerificationGateStatus.check,
          detail: '$overlaps overlap(s)',
        ),
        DebugVerificationGate(
          name: 'Undo available after apply',
          status: _lastUndoAvailableAfterApply
              ? DebugVerificationGateStatus.pass
              : DebugVerificationGateStatus.check,
        ),
        DebugVerificationGate(
          name: 'Undo restored',
          status: undoOk
              ? DebugVerificationGateStatus.pass
              : DebugVerificationGateStatus.check,
          detail: undoWasRun ? null : 'NOT_RUN',
        ),
      ],
    );
    return report.toClipboardText();
  }

  bool _lastPreservedItemsMaintained(DaySchedule after) {
    return _lastPreservedItems.every(
      (item) => after.items.any((candidate) => _sameItem(candidate, item)),
    );
  }

  bool _sameItem(ScheduleItem a, ScheduleItem b) {
    return a.id == b.id &&
        a.type == b.type &&
        a.facilityId == b.facilityId &&
        a.startHour == b.startHour &&
        a.startMinute == b.startMinute &&
        a.endHour == b.endHour &&
        a.endMinute == b.endMinute;
  }

  int _itemDurationMinutes(ScheduleItem item) {
    return _endMinutes(item) - (item.startHour * 60 + item.startMinute);
  }

  int _endMinutes(ScheduleItem item) => item.endHour * 60 + item.endMinute;

  List<String> _overlapDetails(
    DaySchedule schedule, {
    Set<String>? requiredFacilityIds,
  }) {
    final items = schedule.items.where((item) {
      if (item.type == ScheduleItemType.entry ||
          item.type == ScheduleItemType.exit) {
        return false;
      }
      return item.endHour * 60 + item.endMinute >
          item.startHour * 60 + item.startMinute;
    }).toList(growable: false)
      ..sort((a, b) =>
          (a.startHour * 60 + a.startMinute)
              .compareTo(b.startHour * 60 + b.startMinute));
    final details = <String>[];
    for (var i = 0; i < items.length; i++) {
      final left = items[i];
      final leftStart = left.startHour * 60 + left.startMinute;
      final leftEnd = left.endHour * 60 + left.endMinute;
      for (var j = i + 1; j < items.length; j++) {
        final right = items[j];
        final rightStart = right.startHour * 60 + right.startMinute;
        if (rightStart >= leftEnd) break;
        final rightEnd = right.endHour * 60 + right.endMinute;
        if (rightEnd <= leftStart) continue;
        if (requiredFacilityIds != null &&
            !requiredFacilityIds.contains(left.facilityId) &&
            !requiredFacilityIds.contains(right.facilityId)) {
          continue;
        }
        details.add(
          '${left.title} ${left.timeRangeLabel} <-> '
          '${right.title} ${right.timeRangeLabel}',
        );
      }
    }
    return details;
  }


  String _exitText(DaySchedule schedule) {
    for (final item in schedule.items.reversed) {
      if (item.type == ScheduleItemType.exit) {
        return _timeText(item.startHour, item.startMinute);
      }
    }
    return 'none';
  }

  bool _sameSchedule(DaySchedule? a, DaySchedule? b) {
    if (a == null || b == null || a.items.length != b.items.length) return false;
    for (var i = 0; i < a.items.length; i++) {
      final x = a.items[i];
      final y = b.items[i];
      if (x.id != y.id ||
          x.type != y.type ||
          x.facilityId != y.facilityId ||
          x.startHour != y.startHour ||
          x.startMinute != y.startMinute ||
          x.endHour != y.endHour ||
          x.endMinute != y.endMinute) {
        return false;
      }
    }
    return true;
  }

  String _timeText(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}

