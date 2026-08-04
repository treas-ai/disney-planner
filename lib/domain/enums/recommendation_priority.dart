enum RecommendationPriority {
  low,
  normal,
  high,
  urgent;

  String get label {
    return switch (this) {
      RecommendationPriority.low => '低',
      RecommendationPriority.normal => '通常',
      RecommendationPriority.high => '高',
      RecommendationPriority.urgent => '至急',
    };
  }
}
