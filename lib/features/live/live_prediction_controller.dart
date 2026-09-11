import 'package:flutter/foundation.dart';

import '../../data/local/local_history_repository.dart';
import '../../domain/entities/facility.dart';
import '../../domain/entities/live_wait_time.dart';
import '../../domain/entities/time_band_wait_profile.dart';
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
  DateTime _referenceTime = DateTime.now();
  bool _usesVisitDayTargets = true;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get usesVisitDayTargets => _usesVisitDayTargets;

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
    if (predictions.length == 1) {
      return predictions.single;
    }

    return predictions.reduce((left, right) {
      final leftDifference =
          (left.targetTime.difference(_referenceTime).inMinutes -
                  horizon.inMinutes)
              .abs();
      final rightDifference =
          (right.targetTime.difference(_referenceTime).inMinutes -
                  horizon.inMinutes)
              .abs();
      return leftDifference <= rightDifference ? left : right;
    });
  }

  Future<void> load({
    required String parkId,
    required Iterable<Facility> facilities,
    required DateTime referenceTime,
    required bool useVisitDayTargets,
    required List<TimeBandWaitProfile> waitProfiles,
    required LiveWaitTime? Function(String facilityId) currentWaitTimeFor,
    required DateTime? Function(String facilityId) plannedTargetTimeFor,
    int? Function(String facilityId)? planningFallbackMinutesFor,
    String? Function(String facilityId)? planningFallbackReasonFor,
  }) async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _referenceTime = referenceTime;
    _usesVisitDayTargets = useVisitDayTargets;
    notifyListeners();

    try {
      final profileByFacilityId = <String, TimeBandWaitProfile>{
        for (final profile in waitProfiles)
          if (profile.parkId == parkId) profile.facilityId: profile,
      };
      final nextPredictions = <String, List<WaitTimePrediction>>{};

      for (final facility in facilities) {
        final current = useVisitDayTargets
            ? currentWaitTimeFor(facility.id)
            : null;
        final targets = <DateTime>[];

        if (useVisitDayTargets) {
          for (final minutes in const [30, 60, 120]) {
            targets.add(referenceTime.add(Duration(minutes: minutes)));
          }
        } else {
          final plannedTarget = plannedTargetTimeFor(facility.id);
          if (plannedTarget != null) {
            targets.add(plannedTarget);
          }
        }

        if (targets.isEmpty) {
          continue;
        }

        final predictions = <WaitTimePrediction>[];
        for (final targetTime in targets) {
          predictions.add(
            await _engine.predict(
              parkId: parkId,
              facilityId: facility.id,
              targetTime: targetTime,
              currentWaitMinutes: current?.waitMinutes,
              currentWaitUpdatedAt: current?.updatedAt,
              referenceTime: referenceTime,
              waitProfile: profileByFacilityId[facility.id],
              planningFallbackMinutes:
                  planningFallbackMinutesFor?.call(facility.id),
              planningFallbackReason:
                  planningFallbackReasonFor?.call(facility.id),
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
      _errorMessage = '待ち時間予測を更新できませんでした。';
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
