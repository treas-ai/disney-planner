import '../entities/crowd_factor_profile.dart';
import '../entities/wait_time_range.dart';
import '../enums/crowd_factor_confidence.dart';
import 'time_rounding_service.dart';

class CrowdFactorCalculator {
  const CrowdFactorCalculator({
    this.timeRoundingService = const TimeRoundingService(),
  });

  final TimeRoundingService timeRoundingService;

  WaitTimeRange apply({
    required WaitTimeRange baseline,
    required List<CrowdFactorProfile> factors,
  }) {
    var combinedFactor = 1.0;
    for (final profile in factors) {
      combinedFactor *= _dampen(profile.factor);
    }

    return WaitTimeRange(
      minMinutes: timeRoundingService.ceilMinutes(
        (baseline.minMinutes * combinedFactor).round(),
      ),
      typicalMinutes: timeRoundingService.ceilMinutes(
        (baseline.typicalMinutes * combinedFactor).round(),
      ),
      maxMinutes: timeRoundingService.ceilMinutes(
        (baseline.maxMinutes * combinedFactor).round(),
      ),
    );
  }

  CrowdFactorConfidence combinedConfidence(List<CrowdFactorProfile> factors) {
    if (factors.isEmpty) {
      return CrowdFactorConfidence.low;
    }
    if (factors.any(
      (profile) => profile.confidence == CrowdFactorConfidence.low,
    )) {
      return CrowdFactorConfidence.low;
    }
    if (factors.every(
      (profile) => profile.confidence == CrowdFactorConfidence.high,
    )) {
      return CrowdFactorConfidence.high;
    }
    return CrowdFactorConfidence.medium;
  }

  double _dampen(double factor) {
    if (factor >= 1) {
      return 1 + (factor - 1) * 0.75;
    }
    return 1 - (1 - factor) * 0.75;
  }
}
