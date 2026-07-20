import '../../../domain/entities/area.dart';
import '../../../domain/entities/park.dart';
import '../../../domain/entities/resort.dart';
import '../../local/database/app_database.dart';
import '../../models/area_model.dart';
import '../../models/park_model.dart';
import '../../models/resort_model.dart';
import '../park_data_source.dart';

class SQLiteParkDataSource implements ParkDataSource {
  const SQLiteParkDataSource();

  @override
  Future<List<Resort>> getResorts() async {
    final database = await AppDatabase.instance;
    final resortRows = await database.query('resorts', orderBy: 'name ASC');

    final parks = await getParks();

    return resortRows.map((row) {
      final resortId = row['id'] as String? ?? '';

      final parkIds = parks
          .where((park) => park.resortId == resortId)
          .map((park) => park.id)
          .toList();

      return ResortModel.fromMap(row, parkIds: parkIds);
    }).toList();
  }

  @override
  Future<Resort?> getResortById(String resortId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'resorts',
      where: 'id = ?',
      whereArgs: [resortId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final parks = await getParksByResortId(resortId);

    return ResortModel.fromMap(
      rows.first,
      parkIds: parks.map((park) => park.id).toList(),
    );
  }

  @override
  Future<List<Park>> getParks() async {
    final database = await AppDatabase.instance;

    final parkRows = await database.query('parks', orderBy: 'name ASC');

    final areas = await getAreas();

    return parkRows.map((row) {
      final parkId = row['id'] as String? ?? '';

      final areaIds = areas
          .where((area) => area.parkId == parkId)
          .map((area) => area.id)
          .toList();

      return ParkModel.fromMap(row, areaIds: areaIds);
    }).toList();
  }

  @override
  Future<List<Park>> getParksByResortId(String resortId) async {
    final database = await AppDatabase.instance;

    final parkRows = await database.query(
      'parks',
      where: 'resort_id = ?',
      whereArgs: [resortId],
      orderBy: 'name ASC',
    );

    final areas = await getAreas();

    return parkRows.map((row) {
      final parkId = row['id'] as String? ?? '';

      final areaIds = areas
          .where((area) => area.parkId == parkId)
          .map((area) => area.id)
          .toList();

      return ParkModel.fromMap(row, areaIds: areaIds);
    }).toList();
  }

  @override
  Future<Park?> getParkById(String parkId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'parks',
      where: 'id = ?',
      whereArgs: [parkId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final areas = await getAreasByParkId(parkId);

    return ParkModel.fromMap(
      rows.first,
      areaIds: areas.map((area) => area.id).toList(),
    );
  }

  @override
  Future<List<Area>> getAreas() async {
    final database = await AppDatabase.instance;

    final rows = await database.query('areas', orderBy: 'name ASC');

    return rows.map(AreaModel.fromMap).toList();
  }

  @override
  Future<List<Area>> getAreasByParkId(String parkId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'areas',
      where: 'park_id = ?',
      whereArgs: [parkId],
      orderBy: 'name ASC',
    );

    return rows.map(AreaModel.fromMap).toList();
  }

  @override
  Future<Area?> getAreaById(String areaId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'areas',
      where: 'id = ?',
      whereArgs: [areaId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return AreaModel.fromMap(rows.first);
  }
}
