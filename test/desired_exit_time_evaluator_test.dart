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
    expect(result.totalCostMinutes, closeTo(23.33, 0.01));
    expect(result.netValueMinutes, closeTo(6.67, 0.01));
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
    expect(result.totalCostMinutes, 90);
    expect(result.netValueMinutes, -20);
  });

  test('overtime cost increases progressively without a hard cutoff', () {
    final short = evaluator.evaluate(
      desiredExitMinutes: 21 * 60,
      candidateEndMinutes: 21 * 60 + 10,
      experienceValueMinutes: 100,
      opportunityValueMinutes: 0,
    );
    final long = evaluator.evaluate(
      desiredExitMinutes: 21 * 60,
      candidateEndMinutes: 21 * 60 + 40,
      experienceValueMinutes: 100,
      opportunityValueMinutes: 0,
    );

    expect(short.totalCostMinutes / 10, lessThan(long.totalCostMinutes / 40));
    expect(short.shouldAccept, isTrue);
    expect(long.shouldAccept, isTrue);
  });

}
