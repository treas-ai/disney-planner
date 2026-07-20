import '../../domain/entities/facility.dart';
import '../../domain/enums/facility_category.dart';

abstract interface class FacilityDataSource {
  Future<List<Facility>> getFacilities();

  Future<List<Facility>> getFacilitiesByParkId(String parkId);

  Future<List<Facility>> getFacilitiesByAreaId(String areaId);

  Future<List<Facility>> getFacilitiesByCategory(FacilityCategory category);

  Future<Facility?> getFacilityById(String facilityId);
}
