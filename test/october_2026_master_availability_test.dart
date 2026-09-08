import 'package:disney_planner/data/datasources/json/json_facility_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('October attraction closures are applied by selected visit date', () async {
    const dataSource = JsonFacilityDataSource();

    final dumbo = await dataSource.getFacilityById(
      'tdl_fantasyland_dumbo_the_flying_elephant',
    );
    expect(dumbo, isNotNull);
    expect(dumbo!.canAddToPlanAt(DateTime(2026, 10, 22)), isFalse);
    expect(dumbo.canAddToPlanAt(DateTime(2026, 10, 23)), isTrue);

    final tower = await dataSource.getFacilityById('tds_aw_a_002');
    expect(tower, isNotNull);
    expect(tower!.canAddToPlanAt(DateTime(2026, 10, 15)), isFalse);
    expect(tower.canAddToPlanAt(DateTime(2026, 11, 6)), isTrue);
  });

  test('summer entertainment expires and Halloween entertainment replaces it', () async {
    const dataSource = JsonFacilityDataSource();

    final reach = await dataSource.getFacilityById(
      'tdl_world_bazaar_reach_for_the_stars',
    );
    final villains = await dataSource.getFacilityById(
      'tdl_show_villains_halloween_into_the_frenzy',
    );

    expect(reach, isNotNull);
    expect(villains, isNotNull);
    expect(reach!.canAddToPlanAt(DateTime(2026, 9, 14)), isTrue);
    expect(reach.canAddToPlanAt(DateTime(2026, 9, 16)), isFalse);
    expect(villains!.canAddToPlanAt(DateTime(2026, 9, 15)), isFalse);
    expect(villains.canAddToPlanAt(DateTime(2026, 9, 16)), isTrue);
    expect(villains.canAddToPlanAt(DateTime(2026, 11, 1)), isFalse);
  });
}
