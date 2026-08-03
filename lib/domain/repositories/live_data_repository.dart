import '../entities/live_operating_status.dart';
import '../entities/live_pass_status.dart';
import '../entities/live_wait_time.dart';

abstract interface class LiveDataRepository {
  Future<List<LiveWaitTime>> fetchWaitTimes({required String parkId});

  Future<List<LiveOperatingStatus>> fetchOperatingStatuses({
    required String parkId,
  });

  Future<List<LivePassStatus>> fetchPassStatuses({required String parkId});
}
