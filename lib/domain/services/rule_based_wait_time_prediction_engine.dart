import 'dart:math' as math;

import '../entities/activity_history_record.dart';
import '../entities/wait_time_prediction.dart';
import '../enums/activity_history_type.dart';
import '../enums/prediction_confidence.dart';
import '../enums/prediction_source.dart';
import '../repositories/history_repository.dart';
import 'wait_time_prediction_engine.dart';

class RuleBasedWaitTimePredictionEngine implements WaitTimePredictionEngine {
  const RuleBasedWaitTimePredictionEngine(this._historyRepository);

  final HistoryRepository _historyRepository;

  @override
  Future<WaitTimePrediction> predict({
    required String parkId,
    required String facilityId,
    required DateTime targetTime,
    int? currentWaitMinutes,
    DateTime? currentWaitUpdatedAt,
  }) async {
    final now = DateTime.now();
    final records = (await _historyRepository.loadForFacility(facilityId))
        .where(
          (record) =>
              record.parkId == parkId &&
              record.type == ActivityHistoryType.waitTime &&
              record.isTrainingEligible &&
              record.waitMinutes != null,
        )
        .toList(growable: false);

    final comparable = records
        .where((record) {
          final sameWeekday = record.recordedAt.weekday == targetTime.weekday;
          final hourDifference = (record.recordedAt.hour - targetTime.hour)
              .abs();
          return sameWeekday && hourDifference <= 1;
        })
        .toList(growable: false);

    final historyPool = comparable.isNotEmpty ? comparable : records;
    final historyAverage = _average(historyPool);
    final currentIsFresh =
        currentWaitMinutes != null &&
        currentWaitUpdatedAt != null &&
        now.difference(currentWaitUpdatedAt).abs() <= const Duration(hours: 2);

    if (currentWaitMinutes == null && historyAverage == null) {
      return WaitTimePrediction(
        parkId: parkId,
        facilityId: facilityId,
        targetTime: targetTime,
        generatedAt: now,
        confidence: PredictionConfidence.unavailable,
        source: PredictionSource.historyOnly,
        reasons: const ['現在値と学習可能な履歴がありません。'],
      );
    }

    final minutesAhead = math
        .max(0, targetTime.difference(now).inMinutes)
        .toInt();
    final timeAdjustment = _timeAdjustment(targetTime.hour, minutesAhead);
    final reasons = <String>[];
    double base;
    PredictionSource source;

    if (currentWaitMinutes != null && historyAverage != null) {
      final currentWeight = currentIsFresh ? 0.65 : 0.45;
      base =
          currentWaitMinutes * currentWeight +
          historyAverage * (1 - currentWeight);
      source = PredictionSource.hybrid;
      reasons.add('現在の待ち時間と過去の同条件データを組み合わせました。');
    } else if (currentWaitMinutes != null) {
      base = currentWaitMinutes.toDouble();
      source = PredictionSource.currentOnly;
      reasons.add('現在の待ち時間を基準に時間帯補正しました。');
    } else {
      base = historyAverage!;
      source = PredictionSource.historyOnly;
      reasons.add('過去の同曜日・近い時間帯の履歴を基準にしました。');
    }

    if (timeAdjustment != 0) {
      reasons.add(
        timeAdjustment > 0
            ? '混雑しやすい時間帯として上方補正しました。'
            : '比較的落ち着きやすい時間帯として下方補正しました。',
      );
    }

    final predicted = math.max(0, (base + timeAdjustment).round()).toInt();
    final confidence = _confidence(
      sampleCount: historyPool.length,
      hasCurrent: currentWaitMinutes != null,
      currentIsFresh: currentIsFresh,
    );
    final spread = switch (confidence) {
      PredictionConfidence.high =>
        math.max(5, (predicted * 0.12).round()).toInt(),
      PredictionConfidence.medium =>
        math.max(10, (predicted * 0.22).round()).toInt(),
      PredictionConfidence.low =>
        math.max(15, (predicted * 0.35).round()).toInt(),
      PredictionConfidence.unavailable => 0,
    };

    return WaitTimePrediction(
      parkId: parkId,
      facilityId: facilityId,
      targetTime: targetTime,
      generatedAt: now,
      predictedMinutes: predicted,
      lowerBoundMinutes: math.max(0, predicted - spread).toInt(),
      upperBoundMinutes: predicted + spread,
      confidence: confidence,
      source: source,
      reasons: List<String>.unmodifiable(reasons),
      sampleCount: historyPool.length,
    );
  }

  double? _average(List<ActivityHistoryRecord> records) {
    final values = records
        .map((record) => record.waitMinutes)
        .whereType<int>()
        .toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    return values.reduce((left, right) => left + right) / values.length;
  }

  int _timeAdjustment(int hour, int minutesAhead) {
    var adjustment = 0;
    if (hour >= 10 && hour <= 15) {
      adjustment += 10;
    } else if (hour >= 18) {
      adjustment -= 5;
    }
    if (minutesAhead >= 90) {
      adjustment += 5;
    }
    return adjustment;
  }

  PredictionConfidence _confidence({
    required int sampleCount,
    required bool hasCurrent,
    required bool currentIsFresh,
  }) {
    if (hasCurrent && currentIsFresh && sampleCount >= 5) {
      return PredictionConfidence.high;
    }
    if ((hasCurrent && sampleCount >= 2) || sampleCount >= 5) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }
}
