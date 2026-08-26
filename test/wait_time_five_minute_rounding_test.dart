import 'package:disney_planner/domain/services/wait_time_prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = WaitTimePredictionService();

  test('wait prediction values are rounded up to five-minute units', () {
    final estimate = service.estimate(
      baseWaitMinutes: 61,
      volatility: MorningQueueVolatility.medium,
    );

    expect(estimate.expectedMinutes, 65);
    expect(estimate.conservativeMinutes, 80);
    expect(estimate.upperBoundMinutes, 95);
  });

  test('wait prediction keeps exact five-minute values unchanged', () {
    final estimate = service.estimate(
      baseWaitMinutes: 70,
      volatility: MorningQueueVolatility.low,
    );

    expect(estimate.expectedMinutes, 70);
    expect(estimate.conservativeMinutes, 75);
    expect(estimate.upperBoundMinutes, 80);
  });
}
