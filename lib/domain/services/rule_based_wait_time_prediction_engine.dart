import 'dart:math' as math;

import '../entities/activity_history_record.dart';
import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_prediction.dart';
import '../entities/wait_time_range.dart';
import '../enums/activity_history_type.dart';
import '../enums/prediction_confidence.dart';
import '../enums/prediction_source.dart';
import '../enums/wait_time_band.dart';
import '../repositories/history_repository.dart';
import 'time_rounding_service.dart';
import 'wait_time_prediction_engine.dart';

class RuleBasedWaitTimePredictionEngine implements WaitTimePredictionEngine {
  const RuleBasedWaitTimePredictionEngine(
    this._historyRepository, {
    this.timeRoundingService = const TimeRoundingService(),
  });

  final HistoryRepository _historyRepository;
  final TimeRoundingService timeRoundingService;

  @override
  Future<WaitTimePrediction> predict({
    required String parkId,
    required String facilityId,
    required DateTime targetTime,
    int? currentWaitMinutes,
    DateTime? currentWaitUpdatedAt,
    DateTime? referenceTime,
    TimeBandWaitProfile? waitProfile,
    int? planningFallbackMinutes,
    String? planningFallbackReason,
  }) async {
    final generatedAt = DateTime.now();
    final effectiveReferenceTime = referenceTime ?? generatedAt;
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
          final hourDifference = (record.recordedAt.hour - targetTime.hour).abs();
          return sameWeekday && hourDifference <= 1;
        })
        .toList(growable: false);

    final historyPool = comparable.isNotEmpty ? comparable : records;
    final localHistoryAverage = _average(historyPool);
    final profileRange = _reliableRangeFor(waitProfile, targetTime);
    final profileTypical = profileRange?.typicalMinutes.toDouble();
    final profileSamples =
        profileRange?.sampleCount ?? waitProfile?.sampleCount ?? 0;

    final currentIsFresh =
        currentWaitMinutes != null &&
        currentWaitUpdatedAt != null &&
        generatedAt.difference(currentWaitUpdatedAt).abs() <=
            const Duration(hours: 2);

    final historicalBase = _historicalBase(
      profileTypical: profileTypical,
      localHistoryAverage: localHistoryAverage,
    );

    if (currentWaitMinutes == null &&
        historicalBase == null &&
        planningFallbackMinutes == null) {
      return WaitTimePrediction(
        parkId: parkId,
        facilityId: facilityId,
        targetTime: targetTime,
        generatedAt: generatedAt,
        confidence: PredictionConfidence.unavailable,
        source: PredictionSource.historyOnly,
        reasons: const ['収集済み待ち時間実績・現在値・利用可能な計画値がありません。'],
      );
    }

    final reasons = <String>[];
    double base;
    PredictionSource source;

    if (currentWaitMinutes != null && historicalBase != null) {
      final currentWeight = currentIsFresh ? 0.65 : 0.45;
      base = currentWaitMinutes * currentWeight +
          historicalBase * (1 - currentWeight);
      source = profileTypical != null
          ? PredictionSource.currentAndWaitProfile
          : PredictionSource.hybrid;
      reasons.add(
        profileTypical != null
            ? '現在の待ち時間とGitで収集した同時間帯の実績を組み合わせました。'
            : '現在の待ち時間と端末内の過去履歴を組み合わせました。',
      );
    } else if (currentWaitMinutes != null) {
      base = currentWaitMinutes.toDouble();
      source = PredictionSource.currentOnly;
      reasons.add('現在の待ち時間を基準にしました。');
    } else if (historicalBase != null) {
      base = historicalBase;
      source = profileTypical != null
          ? PredictionSource.waitProfile
          : PredictionSource.historyOnly;
      reasons.add(
        profileTypical != null
            ? 'Gitで収集した待ち時間実績のうち、予定時刻に対応する時間帯を使用しました。'
            : '端末内の過去履歴を基準にしました。',
      );
    } else {
      base = planningFallbackMinutes!.toDouble();
      source = PredictionSource.planningFallback;
      reasons.add(
        planningFallbackReason?.trim().isNotEmpty == true
            ? planningFallbackReason!.trim()
            : '実測を取得できないためDisney Plannerの計画値を使用しました。',
      );
    }

    // TimeBandWaitProfile already contains the time-of-day pattern. Avoid
    // adding a second synthetic hour correction when a measured band exists.
    var timeAdjustment = 0;
    if (profileTypical == null && source != PredictionSource.planningFallback) {
      final minutesAhead = math
          .max(0, targetTime.difference(effectiveReferenceTime).inMinutes)
          .toInt();
      timeAdjustment = _timeAdjustment(targetTime.hour, minutesAhead);
      if (timeAdjustment != 0) {
        reasons.add(
          timeAdjustment > 0
              ? '時間帯傾向として上方補正しました。'
              : '時間帯傾向として下方補正しました。',
        );
      }
    }

    final predicted = timeRoundingService.ceilMinutes(
      math.max(0, (base + timeAdjustment).round()).toInt(),
    );

    final effectiveSamples = profileTypical != null
        ? math.max(profileSamples, historyPool.length).toInt()
        : historyPool.length;
    final confidence = _confidence(
      sampleCount: effectiveSamples,
      hasCurrent: currentWaitMinutes != null,
      currentIsFresh: currentIsFresh,
      hasWaitProfile: profileTypical != null,
      usesPlanningFallback: source == PredictionSource.planningFallback,
    );

    final bounds = _predictionBounds(
      predicted: predicted,
      confidence: confidence,
      profileRange: profileRange,
      hasCurrent: currentWaitMinutes != null,
      usesPlanningFallback: source == PredictionSource.planningFallback,
    );

    if (profileRange != null) {
      reasons.add(
        '時間帯サンプル${profileRange.sampleCount ?? waitProfile?.sampleCount ?? 0}件を参照しました。',
      );
    }
    if (source == PredictionSource.planningFallback) {
      reasons.add('この値は実測待ち時間ではありません。');
    }

    return WaitTimePrediction(
      parkId: parkId,
      facilityId: facilityId,
      targetTime: targetTime,
      generatedAt: generatedAt,
      predictedMinutes: predicted,
      lowerBoundMinutes: bounds.$1,
      upperBoundMinutes: bounds.$2,
      confidence: confidence,
      source: source,
      reasons: List<String>.unmodifiable(reasons),
      sampleCount: effectiveSamples,
    );
  }

  double? _historicalBase({
    required double? profileTypical,
    required double? localHistoryAverage,
  }) {
    if (profileTypical != null && localHistoryAverage != null) {
      // The Git profile normally contains far more observations than one
      // device's history, so keep it as the primary baseline.
      return profileTypical * 0.85 + localHistoryAverage * 0.15;
    }
    return profileTypical ?? localHistoryAverage;
  }

  WaitTimeRange? _reliableRangeFor(
    TimeBandWaitProfile? profile,
    DateTime targetTime,
  ) {
    if (profile == null) return null;
    final range = profile.rangeFor(_waitTimeBandForHour(targetTime.hour));
    if (range == null || range.typicalMinutes <= 0) return null;
    if (range.sampleCount != null && range.sampleCount! < 3) return null;
    return range;
  }

  WaitTimeBand _waitTimeBandForHour(int hour) {
    if (hour < 11) return WaitTimeBand.afterOpening;
    if (hour < 12) return WaitTimeBand.beforeLunch;
    if (hour < 15) return WaitTimeBand.afterLunch;
    if (hour < 17) return WaitTimeBand.aroundShows;
    if (hour < 18) return WaitTimeBand.beforeDinner;
    if (hour < 20) return WaitTimeBand.afterDinner;
    return WaitTimeBand.beforeClosing;
  }

  (int, int) _predictionBounds({
    required int predicted,
    required PredictionConfidence confidence,
    required WaitTimeRange? profileRange,
    required bool hasCurrent,
    required bool usesPlanningFallback,
  }) {
    // Wait profile min/max are observed extrema for the whole time band, not
    // a forecast confidence interval. Showing them directly produced ranges
    // such as 50-120 minutes, which are too broad to support planning. Keep
    // the profile typical value as the point forecast and show a narrower
    // uncertainty band around it. When an observed range exists, never expand
    // the guide beyond its observed extrema.
    final spread = switch (confidence) {
      PredictionConfidence.high =>
        math.max(10, (predicted * 0.15).round()).toInt(),
      PredictionConfidence.medium =>
        math.max(15, (predicted * 0.25).round()).toInt(),
      PredictionConfidence.low => math
          .max(
            15,
            (predicted * (usesPlanningFallback ? 0.30 : 0.35)).round(),
          )
          .toInt(),
      PredictionConfidence.unavailable => 0,
    };

    var lower = math.max(0, predicted - spread).toInt();
    var upper = predicted + spread;
    if (profileRange != null) {
      lower = math.max(lower, profileRange.minMinutes).toInt();
      upper = math.min(upper, profileRange.maxMinutes).toInt();
    }

    return (
      timeRoundingService.ceilMinutes(lower),
      timeRoundingService.ceilMinutes(upper),
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
    required bool hasWaitProfile,
    required bool usesPlanningFallback,
  }) {
    if (usesPlanningFallback) {
      return PredictionConfidence.low;
    }
    if (hasWaitProfile && sampleCount >= 100) {
      return PredictionConfidence.high;
    }
    if (hasWaitProfile && sampleCount >= 30) {
      return PredictionConfidence.medium;
    }
    if (hasCurrent && currentIsFresh && sampleCount >= 5) {
      return PredictionConfidence.high;
    }
    if ((hasCurrent && sampleCount >= 2) || sampleCount >= 5) {
      return PredictionConfidence.medium;
    }
    return PredictionConfidence.low;
  }
}
