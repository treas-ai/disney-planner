import '../entities/dpa_strategy.dart';
import '../enums/dpa_strategy_type.dart';

class DpaCandidate {
  const DpaCandidate({
    required this.facilityId,
    required this.isAttraction,
    required this.isShow,
    required this.priorityScore,
    required this.predictedWaitMinutes,
    required this.alternativeWaitMinutes,
  });

  final String facilityId;
  final bool isAttraction;
  final bool isShow;
  final double priorityScore;
  final int predictedWaitMinutes;
  final int alternativeWaitMinutes;

  int get expectedSavedMinutes => predictedWaitMinutes - alternativeWaitMinutes;
}

class DpaStrategyEngine {
  const DpaStrategyEngine();

  List<DpaCandidate> select({
    required DpaStrategy strategy,
    required List<DpaCandidate> candidates,
  }) {
    if (!strategy.isEnabled) {
      return const [];
    }

    final filtered = candidates
        .where((candidate) {
          return switch (strategy.type) {
            DpaStrategyType.attractions => candidate.isAttraction,
            DpaStrategyType.shows => candidate.isShow,
            DpaStrategyType.balanced =>
              candidate.isAttraction || candidate.isShow,
            DpaStrategyType.highCongestionOnly =>
              candidate.predictedWaitMinutes >= 60 &&
                  candidate.expectedSavedMinutes >= 30,
            DpaStrategyType.disabled => false,
          };
        })
        .toList(growable: false);

    filtered.sort((left, right) {
      final leftScore = _score(left, strategy.type);
      final rightScore = _score(right, strategy.type);
      return rightScore.compareTo(leftScore);
    });

    final maxUses = strategy.maxUses;
    if (maxUses == null || maxUses >= filtered.length) {
      return filtered;
    }
    return filtered.take(maxUses).toList(growable: false);
  }

  double _score(DpaCandidate candidate, DpaStrategyType strategy) {
    final saved = candidate.expectedSavedMinutes.clamp(0, 240);
    var score = saved * 1.5 + candidate.priorityScore * 20;

    if (strategy == DpaStrategyType.balanced) {
      score += candidate.isShow ? 10 : 0;
    }
    return score;
  }
}
