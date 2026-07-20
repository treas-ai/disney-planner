import '../../domain/entities/area.dart';
import '../../domain/entities/park.dart';
import '../../domain/entities/resort.dart';

abstract interface class ParkDataSource {
  Future<List<Resort>> getResorts();

  Future<Resort?> getResortById(String resortId);

  Future<List<Park>> getParks();

  Future<List<Park>> getParksByResortId(String resortId);

  Future<Park?> getParkById(String parkId);

  Future<List<Area>> getAreas();

  Future<List<Area>> getAreasByParkId(String parkId);

  Future<Area?> getAreaById(String areaId);
}
