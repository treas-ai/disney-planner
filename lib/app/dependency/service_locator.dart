import '../../data/datasources/mock/mock_facility_data_source.dart';
import '../../data/datasources/mock/mock_park_data_source.dart';
import '../../data/repositories/facility_repository_impl.dart';
import '../../data/repositories/park_repository_impl.dart';
import '../../domain/repositories/facility_repository.dart';
import '../../domain/repositories/park_repository.dart';

class ServiceLocator {
  ServiceLocator._();

  static final MockParkDataSource _parkDataSource = MockParkDataSource();
  static final MockFacilityDataSource _facilityDataSource =
      MockFacilityDataSource();

  static final ParkRepository _parkRepository = ParkRepositoryImpl(
    dataSource: _parkDataSource,
  );

  static final FacilityRepository _facilityRepository = FacilityRepositoryImpl(
    dataSource: _facilityDataSource,
  );

  static ParkRepository get parkRepository => _parkRepository;

  static FacilityRepository get facilityRepository => _facilityRepository;
}