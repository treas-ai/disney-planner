import 'package:flutter/foundation.dart';

import '../../data/local/local_history_repository.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/entities/wait_time_prediction.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/services/rule_based_wait_time_prediction_engine.dart';
import '../../domain/services/wait_time_prediction_engine.dart';

class LivePredictionController extends ChangeNotifier {
  LivePredictionController({
    HistoryRepository? historyRepository,
    WaitTimePredictionEngine? engine,
  }) : _engine =
           engine ??
           RuleBasedWaitTimePredictionEngine(
             historyRepository ?? const LocalHistoryRepository(),
           );

  final WaitTimePredictionEngine _engine;
  final Map<String, List<WaitTimePrediction>> _predictions = {};

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<WaitTimePrediction> predictionsForFacility(String facilityId) {
    return List<WaitTimePrediction>.unmodifiable(
      _predictions[facilityId] ?? const <WaitTimePrediction>[],
    );
  }

  WaitTimePrediction? predictionForFacility(
    String facilityId, {
    Duration horizon = const Duration(hours: 1),
  }) {
    final predictions = _predictions[facilityId];
    if (predictions == null || predictions.isEmpty) {
      return null;
    }

    return predictions.reduce((left, right) {
      final leftDifference =
          (left.targetTime.difference(DateTime.now()).inMinutes -
                  horizon.inMinutes)
              .abs();
      final rightDifference =
          (right.targetTime.difference(DateTime.now()).inMinutes -
                  horizon.inMinutes)
              .abs();
      return leftDifference <= rightDifference ? left : right;
    });
  }

  Future<void> load({
    required String parkId,
    required Iterable<Facility> facilities,
    required LiveWaitTime? Function(String facilityId) currentWaitTimeFor,
  }) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final nextPredictions = <String, List<WaitTimePrediction>>{};

      for (final facility in facilities) {
        final current = currentWaitTimeFor(facility.id);
        final predictions = <WaitTimePrediction>[];
        for (final minutes in const [30, 60, 120]) {
          predictions.add(
            await _engine.predict(
              parkId: parkId,
              facilityId: facility.id,
              targetTime: now.add(Duration(minutes: minutes)),
              currentWaitMinutes: current?.waitMinutes,
              currentWaitUpdatedAt: current?.updatedAt,
            ),
          );
        }
        nextPredictions[facility.id] = predictions;
      }

      _predictions
        ..clear()
        ..addAll(nextPredictions);
    } catch (error, stackTrace) {
      debugPrint('待ち時間予測に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      _errorMessage = 'AI待ち時間予測を更新できませんでした。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }
}
