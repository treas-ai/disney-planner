import '../enums/sellout_risk_level.dart';

class SelloutRiskService {
  const SelloutRiskService();

  SelloutRiskLevel assess({
    required DateTime now,
    required DateTime parkClose,
    bool limitedItem = false,
    bool mustCollect = false,
    bool knownLowStock = false,
  }) {
    if (!limitedItem && !knownLowStock) return SelloutRiskLevel.none;
    if (knownLowStock && mustCollect) return SelloutRiskLevel.high;

    final minutesToClose = parkClose.difference(now).inMinutes;
    if (mustCollect && minutesToClose <= 240) return SelloutRiskLevel.high;
    if (mustCollect || knownLowStock || minutesToClose <= 180) {
      return SelloutRiskLevel.medium;
    }
    return SelloutRiskLevel.low;
  }
}
