import 'time_rounding_service.dart';

enum MorningQueueVolatility { low, medium, high, extreme }

class WaitTimeEstimate {
  const WaitTimeEstimate({
    required this.expectedMinutes,
    required this.conservativeMinutes,
    required this.upperBoundMinutes,
    this.confidence = 0.8,
  });

  final int expectedMinutes;
  final int conservativeMinutes;
  final int upperBoundMinutes;
  final double confidence;
}

class WaitTimePredictionService {
  const WaitTimePredictionService({
    this.timeRoundingService = const TimeRoundingService(),
  });

  final TimeRoundingService timeRoundingService;

  WaitTimeEstimate estimate({
    required int baseWaitMinutes,
    required MorningQueueVolatility volatility,
  }) {
    final add = switch (volatility) {
      MorningQueueVolatility.low => 5,
      MorningQueueVolatility.medium => 15,
      MorningQueueVolatility.high => 30,
      MorningQueueVolatility.extreme => 45,
    };

    final expected = timeRoundingService.ceilMinutes(baseWaitMinutes);
    final conservative = timeRoundingService.ceilMinutes(baseWaitMinutes + add);
    final upper = timeRoundingService.ceilMinutes(baseWaitMinutes + add * 2);

    return WaitTimeEstimate(
      expectedMinutes: expected,
      conservativeMinutes: conservative,
      upperBoundMinutes: upper,
    );
  }
}
