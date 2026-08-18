enum SelloutRiskLevel {
  none,
  low,
  medium,
  high;

  int get score => switch (this) {
        SelloutRiskLevel.none => 0,
        SelloutRiskLevel.low => 1,
        SelloutRiskLevel.medium => 2,
        SelloutRiskLevel.high => 3,
      };
}
