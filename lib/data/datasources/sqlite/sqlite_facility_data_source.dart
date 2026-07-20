import '../../../domain/entities/facility.dart';
import '../../../domain/enums/facility_category.dart';
import '../../local/database/app_database.dart';
import '../../models/facility_model.dart';
import '../facility_data_source.dart';

class SQLiteFacilityDataSource implements FacilityDataSource {
  const SQLiteFacilityDataSource();

  @override
  Future<List<Facility>> getFacilities() async {
    final database = await AppDatabase.instance;

    final rows = await database.query('facilities', orderBy: 'name ASC');

    return rows.map(FacilityModel.fromMap).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: 'park_id = ?',
      whereArgs: [parkId],
      orderBy: 'name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: 'area_id = ?',
      whereArgs: [areaId],
      orderBy: 'name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList();
  }

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: 'category = ?',
      whereArgs: [category.name],
      orderBy: 'name ASC',
    );

    return rows.map(FacilityModel.fromMap).toList();
  }

  @override
  Future<Facility?> getFacilityById(String facilityId) async {
    final database = await AppDatabase.instance;

    final rows = await database.query(
      'facilities',
      where: 'id = ?',
      whereArgs: [facilityId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return FacilityModel.fromMap(rows.first);
  }
}
