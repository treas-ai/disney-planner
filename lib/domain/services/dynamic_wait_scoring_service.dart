import '../entities/time_band_wait_profile.dart';
import '../enums/wait_time_band.dart';

enum WaitPredictionConfidence { none, low, medium, high }

class DynamicWaitScore {
  const DynamicWaitScore({required this.openingMinutes, required this.normalMinutes, required this.savingMinutes, required this.sampleCount, required this.source, required this.confidence, required this.usedFallback});
  final int openingMinutes;
  final int normalMinutes;
  final int savingMinutes;
  final int sampleCount;
  final String source;
  final WaitPredictionConfidence confidence;
  final bool usedFallback;
}

class DynamicWaitScoringService {
  const DynamicWaitScoringService();

  DynamicWaitScore evaluate({required String facilityId, required List<TimeBandWaitProfile> profiles, int? facilityCurrentWaitMinutes, int fallbackMinutes = 30}) {
    TimeBandWaitProfile? profile;
    for (final item in profiles) { if (item.facilityId == facilityId) { profile = item; break; } }
    if (profile == null) {
      final fallback = facilityCurrentWaitMinutes ?? fallbackMinutes;
      return DynamicWaitScore(openingMinutes: fallback, normalMinutes: fallback, savingMinutes: 0, sampleCount: 0, source: facilityCurrentWaitMinutes != null ? '施設の現在待ち時間' : '安全側フォールバック', confidence: WaitPredictionConfidence.none, usedFallback: true);
    }
    final opening = profile.rangeFor(WaitTimeBand.afterOpening)?.typicalMinutes ?? facilityCurrentWaitMinutes ?? fallbackMinutes;
    final normalValues = <int>[
      for (final band in WaitTimeBand.values)
        if (band != WaitTimeBand.afterOpening && profile.rangeFor(band) != null) profile.rangeFor(band)!.typicalMinutes,
    ]..sort();
    final normal = normalValues.isEmpty ? opening : normalValues.length.isOdd ? normalValues[normalValues.length ~/ 2] : ((normalValues[normalValues.length ~/ 2 - 1] + normalValues[normalValues.length ~/ 2]) / 2).round();
    final samples = profile.sampleCount;
    final confidence = samples >= 100 ? WaitPredictionConfidence.high : samples >= 30 ? WaitPredictionConfidence.medium : samples > 0 ? WaitPredictionConfidence.low : WaitPredictionConfidence.none;
    return DynamicWaitScore(openingMinutes: opening, normalMinutes: normal, savingMinutes: (normal - opening).clamp(0, 300), sampleCount: samples, source: profile.source, confidence: confidence, usedFallback: false);
  }
}
