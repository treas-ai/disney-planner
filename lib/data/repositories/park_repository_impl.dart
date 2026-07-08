import '../../domain/entities/area.dart';
import '../../domain/entities/park.dart';
import '../../domain/entities/resort.dart';
import '../../domain/repositories/park_repository.dart';
import '../datasources/mock/mock_park_data_source.dart';

class ParkRepositoryImpl implements ParkRepository {
  const ParkRepositoryImpl({
    required this.dataSource,
  });

  final MockParkDataSource dataSource;

  @override
  Future<List<Resort>> getResorts() async {
    return dataSource.getResorts();
  }

  @override
  Future<Resort?> getResortById(String resortId) async {
    final resorts = dataSource.getResorts();

    for (final resort in resorts) {
      if (resort.id == resortId) {
        return resort;
      }
    }

    return null;
  }

  @override
  Future<List<Park>> getParks() async {
    return dataSource.getParks();
  }

  @override
  Future<List<Park>> getParksByResortId(String resortId) async {
    final parks = dataSource.getParks();

    return parks.where((park) => park.resortId == resortId).toList();
  }

  @override
  Future<Park?> getParkById(String parkId) async {
    final parks = dataSource.getParks();

    for (final park in parks) {
      if (park.id == parkId) {
        return park;
      }
    }

    return null;
  }

  @override
  Future<List<Area>> getAreasByParkId(String parkId) async {
    final areas = dataSource.getAreas();

    return areas.where((area) => area.parkId == parkId).toList();
  }

  @override
  Future<Area?> getAreaById(String areaId) async {
    final areas = dataSource.getAreas();

    for (final area in areas) {
      if (area.id == areaId) {
        return area;
      }
    }

    return null;
  }
}