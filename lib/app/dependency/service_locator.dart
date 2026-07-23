import '../../data/datasources/facility_data_source.dart';
import '../../data/datasources/park_data_source.dart';
import '../../data/datasources/sqlite/sqlite_facility_data_source.dart';
import '../../data/datasources/sqlite/sqlite_park_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/park_repository_impl.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/park_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static const ParkDataSource _parkDataSource = SQLiteParkDataSource();

  static const FacilityDataSource _facilityDataSource =
      SQLiteFacilityDataSource();

  static const ParkRepository _parkRepository = ParkRepositoryImpl(
    dataSource: _parkDataSource,
  );

  static const FacilityRepository _facilityRepository = FacilityRepositoryImpl(
    dataSource: _facilityDataSource,
  );

  static ParkRepository get parkRepository {
    return _parkRepository;
  }

  static FacilityRepository get facilityRepository {
    return _facilityRepository;
  }
}
