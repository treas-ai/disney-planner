import '../../../domain/entities/area.dart';
import '../../../domain/entities/park.dart';
import '../../../domain/entities/resort.dart';
import '../../local/master_data/master_data_validator.dart';
import '../../models/area_model.dart';
import '../../models/park_model.dart';
import '../../models/resort_model.dart';
import '../park_data_source.dart';

class JsonParkDataSource implements ParkDataSource {
  const JsonParkDataSource({this.validator = const MasterDataValidator()});

  static const String _manifestPath = 'assets/master/master_manifest.json';

  static const String _tokyoDisneyResortId = 'tokyo_disney_resort';

  static const String _tokyoDisneyResortName = '東京ディズニーリゾート';

  static const String _tokyoDisneyResortCountry = 'Japan';

  final MasterDataValidator validator;

  static Future<_JsonParkMasterData>? _cachedMasterData;

  @override
  Future<List<Resort>> getResorts() async {
    final masterData = await _loadMasterData();

    return masterData.resorts;
  }

  @override
  Future<Resort?> getResortById(String resortId) async {
    final masterData = await _loadMasterData();

    for (final resort in masterData.resorts) {
      if (resort.id == resortId) {
        return resort;
      }
    }

    return null;
  }

  @override
  Future<List<Park>> getParks() async {
    final masterData = await _loadMasterData();

    return masterData.parks;
  }

  @override
  Future<List<Park>> getParksByResortId(String resortId) async {
    final masterData = await _loadMasterData();

    return List<Park>.unmodifiable(
      masterData.parks.where((park) => park.resortId == resortId),
    );
  }

  @override
  Future<Park?> getParkById(String parkId) async {
    final masterData = await _loadMasterData();

    for (final park in masterData.parks) {
      if (park.id == parkId) {
        return park;
      }
    }

    return null;
  }

  @override
  Future<List<Area>> getAreas() async {
    final masterData = await _loadMasterData();

    return masterData.areas;
  }

  @override
  Future<List<Area>> getAreasByParkId(String parkId) async {
    final masterData = await _loadMasterData();

    return List<Area>.unmodifiable(
      masterData.areas.where((area) => area.parkId == parkId),
    );
  }

  @override
  Future<Area?> getAreaById(String areaId) async {
    final masterData = await _loadMasterData();

    for (final area in masterData.areas) {
      if (area.id == areaId) {
        return area;
      }
    }

    return null;
  }

  Future<_JsonParkMasterData> _loadMasterData() {
    return _cachedMasterData ??= _createMasterData();
  }

  Future<_JsonParkMasterData> _createMasterData() async {
    final validationResult = await validator.validate(
      manifestPath: _manifestPath,
    );

    final areas = validationResult.areaRows
        .map(_createArea)
        .toList(growable: false);

    final parks = validationResult.parkRows
        .map((row) => _createPark(row, areas: areas))
        .toList(growable: false);

    final resortIds = parks
        .map((park) => park.resortId)
        .where((resortId) => resortId.trim().isNotEmpty)
        .toSet();

    final resorts = resortIds
        .map((resortId) => _createResort(resortId, parks: parks))
        .toList(growable: false);

    resorts.sort((left, right) => left.name.compareTo(right.name));

    parks.sort((left, right) => left.name.compareTo(right.name));

    areas.sort((left, right) => left.name.compareTo(right.name));

    return _JsonParkMasterData(
      resorts: List<Resort>.unmodifiable(resorts),
      parks: List<Park>.unmodifiable(parks),
      areas: List<Area>.unmodifiable(areas),
    );
  }

  Area _createArea(Map<String, dynamic> row) {
    final databaseMap = <String, Object?>{
      'id': row['id'],
      'park_id': row['parkId'],
      'name': row['name'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    };

    return AreaModel.fromMap(databaseMap);
  }

  Park _createPark(Map<String, dynamic> row, {required List<Area> areas}) {
    final parkId = _readString(row['id']);

    final areaIds = areas
        .where((area) => area.parkId == parkId)
        .map((area) => area.id)
        .toList(growable: false);

    final databaseMap = <String, Object?>{
      'id': parkId,
      'resort_id': row['resortId'],
      'name': row['name'],
      'open_hour': row['defaultOpenHour'],
      'open_minute': row['defaultOpenMinute'],
      'close_hour': row['defaultCloseHour'],
      'close_minute': row['defaultCloseMinute'],
      'status': row['status'],
    };

    return ParkModel.fromMap(databaseMap, areaIds: areaIds);
  }

  Resort _createResort(String resortId, {required List<Park> parks}) {
    final parkIds = parks
        .where((park) => park.resortId == resortId)
        .map((park) => park.id)
        .toList(growable: false);

    final databaseMap = <String, Object?>{
      'id': resortId,
      'name': _resortName(resortId),
      'country': _resortCountry(resortId),
    };

    return ResortModel.fromMap(databaseMap, parkIds: parkIds);
  }

  String _resortName(String resortId) {
    if (resortId == _tokyoDisneyResortId) {
      return _tokyoDisneyResortName;
    }

    return resortId;
  }

  String _resortCountry(String resortId) {
    if (resortId == _tokyoDisneyResortId) {
      return _tokyoDisneyResortCountry;
    }

    return '';
  }

  String _readString(Object? value) {
    return value is String ? value : '';
  }

  static void clearCache() {
    _cachedMasterData = null;
  }
}

class _JsonParkMasterData {
  const _JsonParkMasterData({
    required this.resorts,
    required this.parks,
    required this.areas,
  });

  final List<Resort> resorts;
  final List<Park> parks;
  final List<Area> areas;
}
