import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/planner_behavior_profile.dart';
import 'package:disney_planner/domain/entities/wait_time_prediction.dart';
import 'package:disney_planner/domain/enums/fatigue_level.dart';
import 'package:disney_planner/domain/enums/live_weather_condition.dart';
import 'package:disney_planner/domain/enums/prediction_confidence.dart';
import 'package:disney_planner/domain/enums/prediction_source.dart';
import 'package:disney_planner/domain/enums/sellout_risk_level.dart';
import 'package:disney_planner/domain/services/advanced_candidate_scoring_service.dart';
import 'package:disney_planner/domain/services/defer_loss_service.dart';
import 'package:disney_planner/domain/services/fatigue_estimation_service.dart';
import 'package:disney_planner/domain/services/sellout_risk_service.dart';

WaitTimePrediction _prediction(int minutes, DateTime time) {
  return WaitTimePrediction(
    parkId: 'tdl',
    facilityId: 'facility',
    targetTime: time,
    generatedAt: time,
    predictedMinutes: minutes,
    lowerBoundMinutes: minutes,
    upperBoundMinutes: minutes,
    confidence: PredictionConfidence.medium,
    source: PredictionSource.historyOnly,
    reasons: const ['test'],
  );
}

void main() {
  test('defer loss captures wait increase when postponing attraction', () {
    final now = DateTime(2026, 8, 12, 9, 15);
    final loss = const DeferLossService().calculate(
      current: _prediction(15, now),
      future: _prediction(55, now.add(const Duration(hours: 3))),
    );
    expect(loss, 40);
  });

  test('defer loss never becomes negative when future wait is shorter', () {
    final now = DateTime(2026, 8, 12, 18);
    final loss = const DeferLossService().calculate(
      current: _prediction(50, now),
      future: _prediction(30, now.add(const Duration(hours: 2))),
    );
    expect(loss, 0);
  });

  test('heavy rain baggage and long stay produce high fatigue', () {
    final level = const FatigueEstimationService().estimate(
      elapsedInPark: const Duration(hours: 8),
      walkingMinutes: 120,
      weather: LiveWeatherCondition.heavyRain,
      hasBaggage: true,
      minutesSinceBreak: 200,
    );
    expect(level, FatigueLevel.high);
  });

  test('must collect limited item near park close has high sellout risk', () {
    final now = DateTime(2026, 8, 12, 17, 30);
    final risk = const SelloutRiskService().assess(
      now: now,
      parkClose: DateTime(2026, 8, 12, 21),
      limitedItem: true,
      mustCollect: true,
    );
    expect(risk, SelloutRiskLevel.high);
  });

  test('advanced score favors large defer loss and route pickup value', () {
    final now = DateTime(2026, 8, 12, 9, 15);
    final service = const AdvancedCandidateScoringService();
    final behavior = PlannerBehaviorProfile.observedAugust2026Trips();

    final strong = service.evaluate(
      wishPriority: 4,
      currentWait: _prediction(15, now),
      futureWait: _prediction(60, now.add(const Duration(hours: 3))),
      behavior: behavior,
      routePickupValue: 2,
    );
    final weak = service.evaluate(
      wishPriority: 4,
      currentWait: _prediction(30, now),
      futureWait: _prediction(30, now.add(const Duration(hours: 3))),
      behavior: behavior,
    );

    expect(strong.deferLossMinutes, 45);
    expect(strong.score, greaterThan(weak.score));
  });
}
