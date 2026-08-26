import 'package:disney_planner/domain/services/desired_exit_time_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evaluator = DesiredExitTimeEvaluator();

  test('candidate within desired exit is always accepted', () {
    final result = evaluator.evaluate(
      desiredExitMinutes: 21 * 60,
      candidateEndMinutes: 20 * 60 + 50,
      experienceValueMinutes: 0,
      opportunityValueMinutes: 0,
    );

    expect(result.shouldAccept, isTrue);
    expect(result.overtimeMinutes, 0);
    expect(result.totalCostMinutes, 0);
  });

  test('positive net value can justify a small exit overrun', () {
    final result = evaluator.evaluate(
      desiredExitMinutes: 21 * 60,
      candidateEndMinutes: 21 * 60 + 20,
      experienceValueMinutes: 25,
      opportunityValueMinutes: 5,
    );

    expect(result.shouldAccept, isTrue);
    expect(result.overtimeMinutes, 20);
    expect(result.totalValueMinutes, 30);
    expect(result.totalCostMinutes, 25);
    expect(result.netValueMinutes, 5);
  });

  test('large overtime is rejected when cost outweighs value', () {
    final result = evaluator.evaluate(
      desiredExitMinutes: 21 * 60,
      candidateEndMinutes: 22 * 60,
      experienceValueMinutes: 65,
      opportunityValueMinutes: 5,
    );

    expect(result.shouldAccept, isFalse);
    expect(result.overtimeMinutes, 60);
    expect(result.totalValueMinutes, 70);
    expect(result.totalCostMinutes, 75);
    expect(result.netValueMinutes, -5);
  });
}
