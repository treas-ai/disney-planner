import '../entities/time_band_wait_profile.dart';
import '../entities/wait_time_prediction.dart';

abstract interface class WaitTimePredictionEngine {
  Future<WaitTimePrediction> predict({
    required String parkId,
    required String facilityId,
    required DateTime targetTime,
    int? currentWaitMinutes,
    DateTime? currentWaitUpdatedAt,
    DateTime? referenceTime,
    TimeBandWaitProfile? waitProfile,
    int? planningFallbackMinutes,
    String? planningFallbackReason,
  });
}
