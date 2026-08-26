class DesiredExitTimeEvaluation {
  const DesiredExitTimeEvaluation({
    required this.shouldAccept,
    required this.overtimeMinutes,
    required this.totalValueMinutes,
    required this.totalCostMinutes,
    required this.netValueMinutes,
  });

  final bool shouldAccept;
  final int overtimeMinutes;
  final double totalValueMinutes;
  final double totalCostMinutes;
  final double netValueMinutes;
}

/// Evaluates whether a candidate that exceeds the user's desired exit time is
/// still worth keeping in the schedule.
///
/// All inputs are normalized to minute-equivalent values so the decision is a
/// continuous comparison rather than a facility-specific rule or fixed
/// overtime threshold. The evaluator intentionally knows nothing about shows,
/// attractions, or facility names; callers provide the value and impact terms.
class DesiredExitTimeEvaluator {
  const DesiredExitTimeEvaluator({this.overtimeCostMultiplier = 1.25});

  /// Soft penalty for deviating from the user's desired exit time. This is a
  /// continuous cost multiplier, not a hard number-of-minutes cutoff.
  final double overtimeCostMultiplier;

  DesiredExitTimeEvaluation evaluate({
    required int desiredExitMinutes,
    required int candidateEndMinutes,
    required double experienceValueMinutes,
    required double opportunityValueMinutes,
    double userPreferenceValueMinutes = 0.0,
    double downstreamImpactMinutes = 0.0,
  }) {
    final overtimeMinutes = candidateEndMinutes > desiredExitMinutes
        ? candidateEndMinutes - desiredExitMinutes
        : 0;

    final totalValueMinutes = _nonNegative(experienceValueMinutes) +
        _nonNegative(opportunityValueMinutes) +
        _nonNegative(userPreferenceValueMinutes);
    final totalCostMinutes = overtimeMinutes.toDouble() *
            _nonNegative(overtimeCostMultiplier) +
        _nonNegative(downstreamImpactMinutes);
    final netValueMinutes = totalValueMinutes - totalCostMinutes;

    return DesiredExitTimeEvaluation(
      shouldAccept: overtimeMinutes == 0 || netValueMinutes > 0,
      overtimeMinutes: overtimeMinutes,
      totalValueMinutes: totalValueMinutes,
      totalCostMinutes: totalCostMinutes,
      netValueMinutes: netValueMinutes,
    );
  }

  double _nonNegative(double value) => value < 0 ? 0 : value;
}
