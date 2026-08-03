import '../enums/prediction_confidence.dart';
import '../enums/prediction_source.dart';

class WaitTimePrediction {
  const WaitTimePrediction({
    required this.parkId,
    required this.facilityId,
    required this.targetTime,
    required this.generatedAt,
    required this.confidence,
    required this.source,
    required this.reasons,
    this.predictedMinutes,
    this.lowerBoundMinutes,
    this.upperBoundMinutes,
    this.sampleCount = 0,
  });

  final String parkId;
  final String facilityId;
  final DateTime targetTime;
  final DateTime generatedAt;
  final int? predictedMinutes;
  final int? lowerBoundMinutes;
  final int? upperBoundMinutes;
  final PredictionConfidence confidence;
  final PredictionSource source;
  final List<String> reasons;
  final int sampleCount;

  bool get isAvailable => predictedMinutes != null;

  String get rangeLabel {
    if (!isAvailable) {
      return '予測データ不足';
    }

    final lower = lowerBoundMinutes;
    final upper = upperBoundMinutes;
    if (lower == null || upper == null || lower == upper) {
      return '$predictedMinutes分';
    }

    return '$lower〜$upper分';
  }
}
