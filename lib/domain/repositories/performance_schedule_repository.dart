import '../entities/performance_time_option.dart';

abstract interface class PerformanceScheduleRepository {
  Future<List<PerformanceTimeOption>> findOptions({
    required String parkId,
    required String facilityId,
    required DateTime date,
  });
}
