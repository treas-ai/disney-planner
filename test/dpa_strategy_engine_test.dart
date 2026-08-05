import 'package:disney_planner/domain/entities/dpa_strategy.dart';
import 'package:disney_planner/domain/enums/dpa_strategy_type.dart';
import 'package:disney_planner/domain/services/dpa_strategy_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('high congestion strategy ignores low-value DPA candidates', () {
    const engine = DpaStrategyEngine();
    const strategy = DpaStrategy(
      type: DpaStrategyType.highCongestionOnly,
      maxUses: 1,
    );

    final selected = engine.select(
      strategy: strategy,
      candidates: const [
        DpaCandidate(
          facilityId: 'short',
          isAttraction: true,
          isShow: false,
          priorityScore: 5,
          predictedWaitMinutes: 40,
          alternativeWaitMinutes: 20,
        ),
        DpaCandidate(
          facilityId: 'long',
          isAttraction: true,
          isShow: false,
          priorityScore: 4,
          predictedWaitMinutes: 120,
          alternativeWaitMinutes: 15,
        ),
      ],
    );

    expect(selected.single.facilityId, 'long');
  });
}
