import 'package:flutter/material.dart';

import '../../app/state/app_state.dart';
import '../../domain/entities/day_schedule.dart';
import '../../domain/services/schedule_engine.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this._appState) {
    _appState.addListener(_onAppStateChanged);
  }

  final AppState _appState;
  final ScheduleEngine _scheduleEngine = const ScheduleEngine();

  bool isLoading = false;
  String? errorMessage;

  DaySchedule? get schedule => _appState.daySchedule;

  bool get canGenerateSchedule {
    return _appState.selectedFacilities.isNotEmpty;
  }

  Future<void> generateSchedule() async {
    if (!canGenerateSchedule) {
      errorMessage = '施設が選択されていません。施設一覧から行きたい施設を追加してください。';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final schedule = _scheduleEngine.generate(
        settings: _appState.tripSettings,
        facilities: _appState.selectedFacilities,
        preferences: _appState.planPreferences,
      );

      _appState.updateDaySchedule(schedule);
    } catch (_) {
      errorMessage = 'スケジュール生成に失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearSchedule() {
    _appState.clearDaySchedule();
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
