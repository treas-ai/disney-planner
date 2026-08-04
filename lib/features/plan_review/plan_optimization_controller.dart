import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state.dart';
import '../../domain/entities/plan_optimization_result.dart';
import '../../domain/entities/wait_time_prediction.dart';
import '../../domain/enums/live_operation_availability.dart';
import '../../domain/enums/prediction_confidence.dart';
import '../../domain/enums/prediction_source.dart';
import '../../domain/services/plan_optimization_engine.dart';
import '../../domain/services/rule_based_plan_optimization_engine.dart';
import '../../domain/services/rule_based_wait_time_prediction_engine.dart';

class PlanOptimizationController extends ChangeNotifier {
  PlanOptimizationController(
    this._appState, {
    this._optimizationEngine = const RuleBasedPlanOptimizationEngine(),
  }) : _predictionEngine = RuleBasedWaitTimePredictionEngine(
         ServiceLocator.historyRepository,
       );

  final AppState _appState;
  final PlanOptimizationEngine _optimizationEngine;
  final RuleBasedWaitTimePredictionEngine _predictionEngine;

  bool isLoading = false;
  String? errorMessage;
  PlanOptimizationResult? result;

  Future<void> analyze() async {
    final schedule = _appState.daySchedule;
    if (schedule == null) {
      errorMessage = '先にプランを生成してください。';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final facilities = _appState.selectedFacilitiesForPark(schedule.parkId);
      final facilityIds = facilities.map((facility) => facility.id).toSet();
      final preferences = _appState.planPreferences
          .where((preference) => facilityIds.contains(preference.facilityId))
          .toList(growable: false);
      final predictions = <String, WaitTimePrediction>{};

      for (final item in schedule.items) {
        final facilityId = item.facilityId;
        if (facilityId == null || predictions.containsKey(facilityId)) {
          continue;
        }
        final now = DateTime.now();
        final targetTime = DateTime(
          now.year,
          now.month,
          now.day,
          item.startHour,
          item.startMinute,
        );
        predictions[facilityId] = await _predictionEngine.predict(
          parkId: schedule.parkId,
          facilityId: facilityId,
          targetTime: targetTime,
        );
      }


      final liveSnapshot = await ServiceLocator.fetchLiveOperationSnapshot(
        parkId: schedule.parkId,
      );
      final freshLimit = DateTime.now().subtract(const Duration(minutes: 30));
      for (final operation in liveSnapshot.attractions) {
        if (operation.updatedAt.isBefore(freshLimit) ||
            operation.availability != LiveOperationAvailability.operating ||
            operation.standbyMinutes == null) {
          continue;
        }

        predictions[operation.facilityId] = WaitTimePrediction(
          parkId: operation.parkId,
          facilityId: operation.facilityId,
          targetTime: DateTime.now(),
          generatedAt: operation.updatedAt,
          predictedMinutes: operation.standbyMinutes,
          lowerBoundMinutes: operation.standbyMinutes,
          upperBoundMinutes: operation.standbyMinutes,
          confidence: PredictionConfidence.high,
          source: PredictionSource.currentOnly,
          reasons: const ['30分以内に手動入力された現在待ち時間'],
        );
      }

      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: schedule.parkId);

      result = _optimizationEngine.optimize(
        schedule: schedule,
        facilities: facilities,
        preferences: preferences,
        predictions: predictions,
        settings: _appState.tripSettings,
        eventImpacts: eventImpacts,
      );
    } catch (error, stackTrace) {
      debugPrint('AIプラン最適化に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'AIプラン評価に失敗しました。もう一度お試しください。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void apply() {
    final current = result;
    if (current == null) {
      return;
    }
    _appState.applyRecalculatedSchedule(current.afterSchedule);
    result = null;
    notifyListeners();
  }
}
