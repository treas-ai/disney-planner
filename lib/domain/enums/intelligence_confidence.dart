enum IntelligenceConfidence {
  unavailable,
  low,
  medium,
  high;

  String get label {
    return switch (this) {
      IntelligenceConfidence.unavailable => '算出不可',
      IntelligenceConfidence.low => '低',
      IntelligenceConfidence.medium => '中',
      IntelligenceConfidence.high => '高',
    };
  }
}
