import '../entities/facility.dart';
import '../enums/facility_category.dart';

abstract class FacilityRepository {
  Future<List<Facility>> getFacilities();

  Future<List<Facility>> getFacilitiesByParkId(String parkId);

  Future<List<Facility>> getFacilitiesByAreaId(String areaId);

  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  );

  Future<Facility?> getFacilityById(String facilityId);
}