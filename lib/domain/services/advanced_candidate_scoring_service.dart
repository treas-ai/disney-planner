import '../entities/advanced_candidate_evaluation.dart';
import '../entities/planner_behavior_profile.dart';
import '../entities/wait_time_prediction.dart';
import '../enums/fatigue_level.dart';
import '../enums/sellout_risk_level.dart';
import 'defer_loss_service.dart';

class AdvancedCandidateScoringService {
  const AdvancedCandidateScoringService({
    this.deferLossService = const DeferLossService(),
  });

  final DeferLossService deferLossService;

  AdvancedCandidateEvaluation evaluate({
    required int wishPriority,
    required WaitTimePrediction currentWait,
    required WaitTimePrediction futureWait,
    required PlannerBehaviorProfile behavior,
    FatigueLevel fatigueLevel = FatigueLevel.low,
    SelloutRiskLevel selloutRisk = SelloutRiskLevel.none,
    int routePickupValue = 0,
    int closingUrgency = 0,
    int expirationUrgency = 0,
    bool indoor = false,
  }) {
    final deferLoss = deferLossService.calculate(
      current: currentWait,
      future: futureWait,
    );
    final fatiguePenalty = switch (fatigueLevel) {
      FatigueLevel.low => 0.0,
      FatigueLevel.medium => indoor ? 2.0 : 8.0,
      FatigueLevel.high => indoor ? 5.0 : 18.0,
    };

    var score = wishPriority * 20.0 * behavior.wishPriorityWeight;
    score += deferLoss * 0.8 * behavior.waitValueWeight;
    score += routePickupValue * 4.0 * behavior.routePickupWeight;
    score += closingUrgency * 5.0 * behavior.closingUrgencyWeight;
    score += expirationUrgency * 7.0 * behavior.expirationUrgencyWeight;
    score += selloutRisk.score * 6.0;
    score -= fatiguePenalty * behavior.comfortWeight;

    final reasons = <String>[
      '希望度$wishPriority/5',
      if (deferLoss > 0) '後回しにすると待ち時間が約$deferLoss分増える見込み',
      if (routePickupValue > 0) '移動ルート上で回収しやすい',
      if (closingUrgency > 0) '営業時間終了が近い',
      if (expirationUrgency > 0) '終了期限が近いWish',
      if (selloutRisk != SelloutRiskLevel.none) '売り切れリスクを考慮',
      if (fatiguePenalty > 0) '疲労・快適性を考慮',
    ];

    return AdvancedCandidateEvaluation(
      score: score,
      currentWaitMinutes: currentWait.predictedMinutes,
      futureWaitMinutes: futureWait.predictedMinutes,
      deferLossMinutes: deferLoss,
      fatiguePenalty: fatiguePenalty,
      selloutRisk: selloutRisk,
      reasons: List<String>.unmodifiable(reasons),
    );
  }
}
