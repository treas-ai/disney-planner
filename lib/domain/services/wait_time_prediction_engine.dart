import '../entities/wait_time_prediction.dart';

abstract interface class WaitTimePredictionEngine {
  Future<WaitTimePrediction> predict({
    required String parkId,
    required String facilityId,
    required DateTime targetTime,
    int? currentWaitMinutes,
    DateTime? currentWaitUpdatedAt,
  });
}
