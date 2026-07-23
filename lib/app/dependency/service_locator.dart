import 'package:flutter/foundation.dart';

import '../../data/datasources/facility_data_source.dart';
import '../../data/datasources/json/json_facility_data_source.dart';
import '../../data/datasources/json/json_park_data_source.dart';
import '../../data/datasources/park_data_source.dart';
import '../../data/datasources/sqlite/sqlite_facility_data_source.dart';
import '../../data/datasources/sqlite/sqlite_park_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/park_repository_impl.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/park_repository.dart';

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

  static ParkRepository get parkRepository {
    return _parkRepository;
  }

  static FacilityRepository get facilityRepository {
    return _facilityRepository;
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
