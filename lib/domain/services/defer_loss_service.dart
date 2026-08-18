import '../entities/wait_time_prediction.dart';

class DeferLossService {
  const DeferLossService();

  int calculate({
    required WaitTimePrediction current,
    required WaitTimePrediction future,
  }) {
    final nowMinutes = current.predictedMinutes;
    final futureMinutes = future.predictedMinutes;
    if (nowMinutes == null || futureMinutes == null) return 0;
    final loss = futureMinutes - nowMinutes;
    return loss > 0 ? loss : 0;
  }
}
