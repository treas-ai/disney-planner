import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/repositories/facility_repository.dart';
import '../datasources/facility_data_source.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  const FacilityRepositoryImpl({required this.dataSource});

  final FacilityDataSource dataSource;

  @override
  Future<List<Facility>> getFacilities() {
    return dataSource.getFacilities();
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) {
    return dataSource.getFacilitiesByParkId(parkId);
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) {
    return dataSource.getFacilitiesByAreaId(areaId);
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(FacilityCategory category) {
    return dataSource.getFacilitiesByCategory(category);
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) {
    return dataSource.getFacilityById(facilityId);
  }
}
