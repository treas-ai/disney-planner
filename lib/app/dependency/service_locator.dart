import 'package:flutter/foundation.dart';

import '../../data/datasources/facility_data_source.dart';
import '../../data/datasources/json/json_facility_data_source.dart';
import '../../data/datasources/json/json_park_data_source.dart';
import '../../data/datasources/park_data_source.dart';
import '../../data/datasources/sqlite/sqlite_facility_data_source.dart';
import '../../data/datasources/sqlite/sqlite_park_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/park_repository_impl.dart';
import '../../data/local/local_event_impact_repository.dart';
import '../../data/local/local_history_repository.dart';
import '../../data/local/live_data_source_preferences.dart';
import '../../data/local/manual_wait_time_store.dart';
import '../../data/providers/cached_live_data_provider.dart';
import '../../data/providers/mock_live_data_provider.dart';
import '../../data/providers/manual_live_data_provider.dart';
import '../../data/providers/official_live_data_provider.dart';
import '../../data/repositories/live_operation_repository_impl.dart';
import '../../data/local/local_movement_repository.dart';
import '../../domain/repositories/event_impact_repository.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/park_repository.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/enums/live_data_source_type.dart';
import '../../domain/repositories/live_operation_repository.dart';
import '../../domain/repositories/movement_repository.dart';
import '../../domain/services/basic_learning_engine.dart';
import '../../domain/services/learning_engine.dart';

class ServiceLocator {
  ServiceLocator._();

  static final ParkDataSource _parkDataSource = _createParkDataSource();

  static final FacilityDataSource _facilityDataSource =
      _createFacilityDataSource();

  static final ParkRepository _parkRepository = ParkRepositoryImpl(
    dataSource: _parkDataSource,
  );

  static final FacilityRepository _facilityRepository = FacilityRepositoryImpl(
    dataSource: _facilityDataSource,
  );

  static const MovementRepository _movementRepository =
      LocalMovementRepository();

  static const EventImpactRepository _eventImpactRepository =
      LocalEventImpactRepository();

  static const HistoryRepository _historyRepository = LocalHistoryRepository();

  static const LearningEngine _learningEngine = BasicLearningEngine();

  static const LiveDataSourcePreferences _liveDataSourcePreferences =
      LiveDataSourcePreferences();

  static const ManualWaitTimeStore _manualWaitTimeStore = ManualWaitTimeStore();

  static final LiveDataMemoryCache _liveDataCache = LiveDataMemoryCache();

  static const LiveOperationRepository _liveOperationRepository =
      LiveOperationRepositoryImpl(provider: MockLiveDataProvider());

  static ParkRepository get parkRepository {
    return _parkRepository;
  }

  static FacilityRepository get facilityRepository {
    return _facilityRepository;
  }

  static MovementRepository get movementRepository {
    return _movementRepository;
  }

  static EventImpactRepository get eventImpactRepository {
    return _eventImpactRepository;
  }

  static HistoryRepository get historyRepository {
    return _historyRepository;
  }

  static LearningEngine get learningEngine {
    return _learningEngine;
  }

  static LiveOperationRepository get liveOperationRepository {
    return _liveOperationRepository;
  }

  static LiveDataSourcePreferences get liveDataSourcePreferences {
    return _liveDataSourcePreferences;
  }

  static ManualWaitTimeStore get manualWaitTimeStore {
    return _manualWaitTimeStore;
  }

  static Future<LiveOperationSnapshot> fetchLiveOperationSnapshot({
    required String parkId,
  }) async {
    final sourceType = await _liveDataSourcePreferences.load();
    const mockProvider = MockLiveDataProvider();

    final provider = switch (sourceType) {
      LiveDataSourceType.mock => CachedLiveDataProvider(
        primary: mockProvider,
        fallback: mockProvider,
        cache: _liveDataCache,
      ),
      LiveDataSourceType.manual => CachedLiveDataProvider(
        primary: const ManualLiveDataProvider(store: _manualWaitTimeStore),
        fallback: mockProvider,
        cache: _liveDataCache,
      ),
      LiveDataSourceType.official => CachedLiveDataProvider(
        primary: OfficialLiveDataProvider(),
        fallback: mockProvider,
        cache: _liveDataCache,
      ),
    };

    final repository = LiveOperationRepositoryImpl(provider: provider);
    return repository.fetchSnapshot(parkId: parkId);
  }

  static void clearLiveDataCache() {
    _liveDataCache.clear();
  }

  static ParkDataSource _createParkDataSource() {
    if (kIsWeb) {
      return const JsonParkDataSource();
    }

    return const SQLiteParkDataSource();
  }

  static FacilityDataSource _createFacilityDataSource() {
    if (kIsWeb) {
      return const JsonFacilityDataSource();
    }

    return const SQLiteFacilityDataSource();
  }

  static void clearWebMasterDataCache() {
    if (!kIsWeb) {
      return;
    }

    JsonParkDataSource.clearCache();
    JsonFacilityDataSource.clearCache();
  }
}
