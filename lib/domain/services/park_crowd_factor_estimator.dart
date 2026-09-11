import '../entities/crowd_factor_profile.dart';

class ParkCrowdFactorEstimator {
  const ParkCrowdFactorEstimator();

  double estimate({
    required List<CrowdFactorProfile> factors,
    required DateTime targetDate,
    double maximumMultiplier = 1.75,
  }) {
    if (factors.isEmpty) return 1.0;

    final weekdayKey = 'weekday:${targetDate.weekday}';
    final seasonKey = 'season:${_season(targetDate.month)}';

    final weekdayFactors = <double>[
      for (final factor in factors)
        if (factor.sampleCount >= 30 && factor.dimensions.contains(weekdayKey))
          factor.factor,
    ];
    final seasonFactors = <double>[
      for (final factor in factors)
        if (factor.sampleCount >= 30 && factor.dimensions.contains(seasonKey))
          factor.factor,
    ];

    final weekday = _upperQuartile(weekdayFactors);
    final season = _upperQuartile(seasonFactors);

    // A greeting has no facility-specific measured factor. Reuse the
    // upper-middle park tendency from the collected attraction history, but
    // never lower the safe fallback below 1.0 or multiply independent factors
    // together. This avoids turning limited proxy data into false precision.
    final estimate = [1.0, weekday, season].reduce((a, b) => a >= b ? a : b);
    return estimate.clamp(1.0, maximumMultiplier).toDouble();
  }

  double _upperQuartile(List<double> values) {
    if (values.isEmpty) return 1.0;
    final sorted = [...values]..sort();
    final index = ((sorted.length * 0.75).ceil() - 1)
        .clamp(0, sorted.length - 1)
        .toInt();
    return sorted[index];
  }

  String _season(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }
}
