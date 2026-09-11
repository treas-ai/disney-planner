import 'package:flutter/foundation.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/live_operating_status.dart';
import '../../domain/entities/schedule_recalculation_request.dart';
import '../../domain/entities/schedule_recalculation_result.dart';
import '../../domain/entities/weather_snapshot.dart';
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

  bool get isCalculating => _isCalculating;
  String? get errorMessage => _errorMessage;
  ScheduleRecalculationResult? get pendingResult => _pendingResult;
  bool get canApply => _pendingResult != null;
  bool get canUndo => _liveController.simulationEnabled
      ? _liveController.canUndoSimulationSchedule
      : _appState.canUndoScheduleChange;
  Set<String> get suspendedFacilityIds => _liveController.suspendedFacilityIds;

  bool isSuspended(String facilityId) {
    return _liveController.isFacilitySuspended(facilityId);
  }

  void suspendFacility(String facilityId) {
    _liveController.suspendFacility(facilityId);
  }

  void resumeFacility(String facilityId) {
    _liveController.resumeFacility(facilityId);
  }

  Future<ScheduleRecalculationResult?> createProposal() async {
    final schedule = _liveController.schedule;
    if (schedule == null) {
      _errorMessage = '再計算するスケジュールがありません。';
      notifyListeners();
      return null;
    }

    _isCalculating = true;
    _errorMessage = null;
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

      _pendingResult = _service.createProposal(
        ScheduleRecalculationRequest(
          now: _liveController.now,
          currentSchedule: schedule,
          settings: _appState.tripSettings,
          facilities: _appState.selectedFacilitiesForPark(schedule.parkId),
          preferences: _appState.planPreferences,
          waitTimes: waitTimes.cast(),
          operatingStatuses: operating.cast(),
          weather: _appState.tripSettings.isRainy
              ? WeatherSnapshot(
                  condition: LiveWeatherCondition.rain,
                  updatedAt: _liveController.now,
                )
              : null,
          passStatuses: _liveController.liveDataController.passStatuses,
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
    if (_liveController.simulationEnabled) {
      _liveController.applySimulationSchedule(result.afterSchedule);
    } else {
      _appState.applyRecalculatedSchedule(result.afterSchedule);
    }
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
    notifyListeners();
  }
}
