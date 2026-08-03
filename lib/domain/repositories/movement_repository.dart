import '../entities/area_connection.dart';
import '../entities/facility_location.dart';

abstract interface class MovementRepository {
  Future<List<FacilityLocation>> loadFacilityLocations({
    required String parkId,
  });

  Future<List<AreaConnection>> loadAreaConnections({required String parkId});
}
