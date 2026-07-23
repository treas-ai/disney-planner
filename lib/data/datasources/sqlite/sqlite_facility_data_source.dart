import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import '../../local/database/app_database.dart';
import '../../models/facility_model.dart';
import '../facility_data_source.dart';

class SQLiteFacilityDataSource implements FacilityDataSource {
  const SQLiteFacilityDataSource();

  static const String _serviceCategoryName = 'service';

  @override
  Future<List<Facility>> getFacilities() async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: 'category != ?',
      whereArgs: const [_serviceCategoryName],
      orderBy: 'park_id ASC, area_id ASC, display_order ASC, name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: '''
        park_id = ?
        AND category != ?
      ''',
      whereArgs: [parkId, _serviceCategoryName],
      orderBy: 'area_id ASC, display_order ASC, name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: '''
        area_id = ?
        AND category != ?
      ''',
      whereArgs: [areaId, _serviceCategoryName],
      orderBy: 'display_order ASC, name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: '''
        category = ?
        AND category != ?
      ''',
      whereArgs: [category.name, _serviceCategoryName],
      orderBy: 'park_id ASC, area_id ASC, display_order ASC, name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList(growable: false);
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: '''
        id = ?
        AND category != ?
      ''',
      whereArgs: [facilityId, _serviceCategoryName],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return FacilityModel.fromMap(rows.first);
  }
}
