import '../entities/live_wait_time.dart';

abstract interface class LiveWaitTimeRepository {
  Future<List<LiveWaitTime>> loadAll();

  Future<List<LiveWaitTime>> loadForPark(String parkId);

  Future<LiveWaitTime?> loadForFacility(String facilityId);

  Future<void> save(LiveWaitTime waitTime);

  Future<void> remove(String facilityId);

  Future<void> clearForPark(String parkId);

  Future<void> clearAll();
}
