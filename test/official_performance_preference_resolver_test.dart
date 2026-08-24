import 'package:disney_planner/data/local/local_performance_schedule_repository.dart';
import 'package:disney_planner/domain/entities/facility.dart';
import 'package:disney_planner/domain/entities/plan_preference.dart';
import 'package:disney_planner/domain/enums/facility_category.dart';
import 'package:disney_planner/domain/enums/facility_access_method.dart';
import 'package:disney_planner/domain/enums/fixed_time_status.dart';
import 'package:disney_planner/domain/services/official_performance_preference_resolver.dart';
import 'package:disney_planner/domain/value_objects/coordinate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official single performance is automatically confirmed', () async {
    final resolver = OfficialPerformancePreferenceResolver(
      repository: LocalPerformanceScheduleRepository(),
    );
    const facility = Facility(
      id: 'tdl_world_bazaar_electrical_parade_dreamlights',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_world_bazaar',
      name: '東京ディズニーランド・エレクトリカルパレード・ドリームライツ',
      category: FacilityCategory.parade,
      coordinate: Coordinate(latitude: 0, longitude: 0),
    );

    final resolved = await resolver.resolve(
      parkId: 'tokyo_disneyland',
      date: DateTime(2026, 8, 4),
      entryMinutes: 9 * 60,
      exitMinutes: 21 * 60,
      facilities: const [facility],
      preferences: [PlanPreference.initial(facilityId: facility.id)],
    );

    expect(resolved.single.fixedTimeStatus, FixedTimeStatus.confirmed);
    expect(resolved.single.preferredPerformanceTime, '19:45');
  });

  test('entry request performance is planned, not confirmed before lottery', () async {
    final resolver = OfficialPerformancePreferenceResolver(
      repository: LocalPerformanceScheduleRepository(),
    );
    const facility = Facility(
      id: 'tdl_world_bazaar_electrical_parade_dreamlights',
      parkId: 'tokyo_disneyland',
      areaId: 'tdl_world_bazaar',
      name: '抽選対象テスト公演',
      category: FacilityCategory.parade,
      coordinate: Coordinate(latitude: 0, longitude: 0),
      requiresEntryRequest: true,
      supportsDpa: true,
    );
    final preference = PlanPreference.initial(facilityId: facility.id).copyWith(
      accessMethod: FacilityAccessMethod.entryRequest,
    );

    final resolved = await resolver.resolve(
      parkId: 'tokyo_disneyland',
      date: DateTime(2026, 8, 4),
      entryMinutes: 9 * 60,
      exitMinutes: 21 * 60,
      facilities: const [facility],
      preferences: [preference],
    );

    expect(resolved.single.fixedTimeStatus, FixedTimeStatus.planned);
    expect(resolved.single.preferredPerformanceTime, '19:45');
  });

}
