import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';
import '../../domain/repositories/facility_repository.dart';
import '../datasources/mock/mock_facility_data_source.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  const FacilityRepositoryImpl({
    required this.dataSource,
  });

  final MockFacilityDataSource dataSource;

  @override
  Future<List<Facility>> getFacilities() async {
    return dataSource.getFacilities();
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async {
    final facilities = dataSource.getFacilities();

    return facilities.where((facility) => facility.parkId == parkId).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async {
    final facilities = dataSource.getFacilities();

    return facilities.where((facility) => facility.areaId == areaId).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async {
    final facilities = dataSource.getFacilities();

    return facilities
        .where((facility) => facility.category == category)
        .toList();
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) async {
    final facilities = dataSource.getFacilities();

    for (final facility in facilities) {
      if (facility.id == facilityId) {
        return facility;
      }
    }

    return null;
  }
}