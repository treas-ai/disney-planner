import '../entities/activity_history_record.dart';
import '../enums/activity_history_type.dart';

abstract interface class HistoryRepository {
  Future<List<ActivityHistoryRecord>> loadAll();

  Future<List<ActivityHistoryRecord>> loadForPark(String parkId);

  Future<List<ActivityHistoryRecord>> loadForFacility(String facilityId);

  Future<List<ActivityHistoryRecord>> loadByType(ActivityHistoryType type);

  Future<void> save(ActivityHistoryRecord record);

  Future<void> saveAll(Iterable<ActivityHistoryRecord> records);

  Future<void> remove(String recordId);

  Future<void> clearAll();
}
