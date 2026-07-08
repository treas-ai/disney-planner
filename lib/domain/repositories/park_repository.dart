import '../entities/area.dart';
import '../entities/park.dart';
import '../entities/resort.dart';

abstract class ParkRepository {
  Future<List<Resort>> getResorts();

  Future<Resort?> getResortById(String resortId);

  Future<List<Park>> getParks();

  Future<List<Park>> getParksByResortId(String resortId);

  Future<Park?> getParkById(String parkId);

  Future<List<Area>> getAreasByParkId(String parkId);

  Future<Area?> getAreaById(String areaId);
}