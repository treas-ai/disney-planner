import '../enums/sellout_risk_level.dart';

class AdvancedCandidateEvaluation {
  const AdvancedCandidateEvaluation({
    required this.score,
    required this.currentWaitMinutes,
    required this.futureWaitMinutes,
    required this.deferLossMinutes,
    required this.fatiguePenalty,
    required this.selloutRisk,
    required this.reasons,
  });

  final double score;
  final int? currentWaitMinutes;
  final int? futureWaitMinutes;

  /// 今行かずに後回しにした場合に増えると予測される待ち時間。
  final int deferLossMinutes;

  final double fatiguePenalty;
  final SelloutRiskLevel selloutRisk;
  final List<String> reasons;
}
