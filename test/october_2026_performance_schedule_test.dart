import 'package:disney_planner/data/local/local_performance_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('October Halloween and TDS evening schedules are bundled', () async {
    final repository = LocalPerformanceScheduleRepository();
    final villains = await repository.findOptions(
      parkId: 'tokyo_disneyland',
      facilityId: 'tdl_show_villains_halloween_into_the_frenzy',
      date: DateTime(2026, 10, 31),
    );
    expect(villains.map((option) => option.startTime), ['13:00']);

    final believe = await repository.findOptions(
      parkId: 'tokyo_disneysea',
      facilityId: 'tds_show_believe_sea_of_dreams',
      date: DateTime(2026, 10, 15),
    );
    expect(believe.map((option) => option.startTime), ['19:30']);
  });

  test('TDL 10/2 closed nighttime entertainment has no schedule', () async {
    final repository = LocalPerformanceScheduleRepository();
    final electrical = await repository.findOptions(
      parkId: 'tokyo_disneyland',
      facilityId: 'tdl_world_bazaar_electrical_parade_dreamlights',
      date: DateTime(2026, 10, 2),
    );
    final nightHigh = await repository.findOptions(
      parkId: 'tokyo_disneyland',
      facilityId: 'tdl_show_night_high_halloween',
      date: DateTime(2026, 10, 2),
    );
    expect(electrical, isEmpty);
    expect(nightHigh, isEmpty);
  });
}
