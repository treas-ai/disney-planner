import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_range.dart';
import '../enums/wait_time_band.dart';

class OpeningCrowdBehaviorEvaluation {
  const OpeningCrowdBehaviorEvaluation({
    required this.usable,
    required this.openingWaitMinutes,
    required this.beforeLunchWaitMinutes,
    required this.rawChangeMinutes,
    required this.weightedValueMinutes,
    required this.confidenceWeight,
    required this.reason,
  });

  final bool usable;
  final int openingWaitMinutes;
  final int beforeLunchWaitMinutes;

  /// Positive: postponing toward late morning is likely to cost time.
  /// Negative: the attraction is unusually crowded just after opening.
  final int rawChangeMinutes;

  /// Data-confidence weighted value used by the first-move scorer.
  final double weightedValueMinutes;
  final double confidenceWeight;
  final String reason;
}

/// Evaluates the *observed* opening crowd response of an attraction.
///
/// This intentionally does not hard-code "popular rides" or park geography.
/// Instead it compares reliable historical wait bands:
///   opening -> before lunch
///
/// If waits rise after opening, the low-wait opening window is valuable.
/// If waits are already inflated at opening and then fall, the opening rush is
/// treated as a cost rather than a reason to join the crowd.
class OpeningCrowdBehaviorEvaluator {
  const OpeningCrowdBehaviorEvaluator();

  OpeningCrowdBehaviorEvaluation evaluate({
    required String facilityId,
    required String parkId,
    required List<TimeBandWaitProfile> profiles,
  }) {
    TimeBandWaitProfile? profile;
    for (final item in profiles) {
      if (item.facilityId == facilityId && item.parkId == parkId) {
        profile = item;
        break;
      }
    }

    if (profile == null) {
      return const OpeningCrowdBehaviorEvaluation(
        usable: false,
        openingWaitMinutes: 0,
        beforeLunchWaitMinutes: 0,
        rawChangeMinutes: 0,
        weightedValueMinutes: 0,
        confidenceWeight: 0,
        reason: '朝の群集変化を判断できる実績データなし',
      );
    }

    final opening = profile.rangeFor(WaitTimeBand.afterOpening);
    final beforeLunch = profile.rangeFor(WaitTimeBand.beforeLunch);
    if (!_isReliable(opening) || !_isReliable(beforeLunch)) {
      return const OpeningCrowdBehaviorEvaluation(
        usable: false,
        openingWaitMinutes: 0,
        beforeLunchWaitMinutes: 0,
        rawChangeMinutes: 0,
        weightedValueMinutes: 0,
        confidenceWeight: 0,
        reason: '朝の時間帯別サンプルが不足しているため群集補正なし',
      );
    }

    final sampleCount = _minimum(
      opening!.sampleCount ?? 0,
      beforeLunch!.sampleCount ?? 0,
    );
    final confidenceWeight = switch (sampleCount) {
      >= 30 => 1.0,
      >= 10 => 0.75,
      _ => 0.5,
    };

    final rawChange = beforeLunch.typicalMinutes - opening.typicalMinutes;
    final cappedChange = rawChange.clamp(-45, 45);
    final weighted = cappedChange * confidenceWeight;

    final reason = rawChange > 0
        ? '開園直後${opening.typicalMinutes}分→昼前${beforeLunch.typicalMinutes}分。'
            '朝の低待ち時間が失われる実績を+$rawChange分として評価'
        : rawChange < 0
            ? '開園直後${opening.typicalMinutes}分→昼前${beforeLunch.typicalMinutes}分。'
                '開園直後の群集集中を${-rawChange}分相当のコストとして評価'
            : '開園直後と昼前の代表待ち時間が同等のため群集補正なし';

    return OpeningCrowdBehaviorEvaluation(
      usable: true,
      openingWaitMinutes: opening.typicalMinutes,
      beforeLunchWaitMinutes: beforeLunch.typicalMinutes,
      rawChangeMinutes: rawChange,
      weightedValueMinutes: weighted.toDouble(),
      confidenceWeight: confidenceWeight,
      reason: reason,
    );
  }

  bool _isReliable(WaitTimeRange? range) {
    if (range == null || range.typicalMinutes <= 0) return false;
    final samples = range.sampleCount;
    return samples == null || samples >= 3;
  }

  int _minimum(int first, int second) => first <= second ? first : second;
}
