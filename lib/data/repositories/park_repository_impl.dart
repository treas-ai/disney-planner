import '../../domain/entities/area.dart';
import '../../domain/entities/park.dart';
import '../../domain/entities/resort.dart';
import '../../domain/repositories/park_repository.dart';
import '../datasources/park_data_source.dart';

class ParkRepositoryImpl implements ParkRepository {
  const ParkRepositoryImpl({required this.dataSource});

  final ParkDataSource dataSource;

  @override
  Future<List<Resort>> getResorts() {
    return dataSource.getResorts();
  }

  @override
  Future<Resort?> getResortById(String resortId) {
    return dataSource.getResortById(resortId);
  }

  @override
  Future<List<Park>> getParks() {
    return dataSource.getParks();
  }

  @override
  Future<List<Park>> getParksByResortId(String resortId) {
    return dataSource.getParksByResortId(resortId);
  }

  @override
  Future<Park?> getParkById(String parkId) {
    return dataSource.getParkById(parkId);
  }

  @override
  Future<List<Area>> getAreasByParkId(String parkId) {
    return dataSource.getAreasByParkId(parkId);
  }

  @override
  Future<Area?> getAreaById(String areaId) {
    return dataSource.getAreaById(areaId);
  }
}
