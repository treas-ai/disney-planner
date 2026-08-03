import '../../domain/entities/area_connection.dart';
import '../../domain/entities/facility_location.dart';
import '../../domain/repositories/movement_repository.dart';

class ApiMovementRepository implements MovementRepository {
  const ApiMovementRepository();

  @override
  Future<List<AreaConnection>> loadAreaConnections({required String parkId}) {
    throw UnimplementedError('移動時間APIはv3.0以降で実装します。');
  }

  @override
  Future<List<FacilityLocation>> loadFacilityLocations({
    required String parkId,
  }) {
    throw UnimplementedError('位置情報APIはv3.0以降で実装します。');
  }
}
