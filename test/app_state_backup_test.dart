import 'package:disney_planner/app/state/app_state.dart';
import 'package:disney_planner/data/local/app_state_storage.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/repositories/facility_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyFacilityRepository implements FacilityRepository {
  @override
  Future<Facility?> getFacilityById(String facilityId) async => null;

  @override
  Future<List<Facility>> getFacilities() async => const [];

  @override
  Future<List<Facility>> getFacilitiesByAreaId(String areaId) async => const [];

  @override
  Future<List<Facility>> getFacilitiesByCategory(
    FacilityCategory category,
  ) async => const [];

  @override
  Future<List<Facility>> getFacilitiesByParkId(String parkId) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup JSON contains schema and appState', () {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(
      storage: AppStateStorage(),
      facilityRepository: _EmptyFacilityRepository(),
    );

    final backup = state.exportBackupJson();

    expect(backup, contains('"schemaVersion": 1'));
    expect(backup, contains('"appState"'));
  });
}
