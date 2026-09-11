class FreeTimeImprovementScoringService {
  const FreeTimeImprovementScoringService();

  double scoreFacility({
    required int priorityValue,
    required int plannedDurationMinutes,
    required int movementInMinutes,
    required int movementOutMinutes,
    required int fitSlackMinutes,
    required bool isWishlisted,
    required bool samePreviousArea,
    required bool sameNextArea,
    required bool isGreeting,
    double expertScore = 0,
    int estimatedWaitMinutes = 0,
    int? gapMinutes,
  }) {
    final totalMovement = movementInMinutes + movementOutMinutes;
    final waitMinutes =
        estimatedWaitMinutes.clamp(0, plannedDurationMinutes).toInt();
    final experienceMinutes = (plannedDurationMinutes - waitMinutes)
        .clamp(0, plannedDurationMinutes)
        .toInt();
    final effectiveGapMinutes =
        gapMinutes ?? plannedDurationMinutes + fitSlackMinutes;
    final usedMinutes = (effectiveGapMinutes - fitSlackMinutes)
        .clamp(0, effectiveGapMinutes)
        .toInt();
    final utilizationRatio = effectiveGapMinutes <= 0
        ? 0.0
        : usedMinutes / effectiveGapMinutes;

    double score;
    if (isWishlisted) {
      // Explicit user intent remains the strongest signal.
      score = priorityValue * 28.0 + 120.0;
      score += expertScore * 0.25;
      score -= waitMinutes * 0.12;
      score -= totalMovement * 0.65;
      score -= fitSlackMinutes.clamp(0, 180) * 0.02;
    } else {
      // "New recommendations" should optimize the value of the free slot,
      // not merely choose the shortest facility that technically fits.
      score = expertScore * 0.85;
      score += priorityValue * 4.0;
      score += experienceMinutes * 0.18;
      score += utilizationRatio * 20.0;
      score -= waitMinutes * 0.18;
      score -= totalMovement * 0.70;
      score -= fitSlackMinutes.clamp(0, 180) * 0.08;
    }

    if (samePreviousArea) score += 10;
    if (sameNextArea) score += 8;

    // Unselected greetings are valid new recommendations, but their category
    // alone must not push them above higher-value experiences.
    if (isGreeting && !isWishlisted) {
      score -= 18;
    }

    return score;
  }
}
