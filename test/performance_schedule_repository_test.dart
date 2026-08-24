import 'package:disney_planner/data/local/local_performance_schedule_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('2026-08-04 official TDL parade time is loaded', () async {
    final repository = LocalPerformanceScheduleRepository();
    final options = await repository.findOptions(
      parkId: 'tokyo_disneyland',
      facilityId: 'tdl_world_bazaar_electrical_parade_dreamlights',
      date: DateTime(2026, 8, 4),
    );

    expect(options, hasLength(1));
    expect(options.single.startTime, '19:45');
  });

  test('2026-08-04 official TDS Believe time is loaded', () async {
    final repository = LocalPerformanceScheduleRepository();
    final options = await repository.findOptions(
      parkId: 'tokyo_disneysea',
      facilityId: 'tds_show_believe_sea_of_dreams',
      date: DateTime(2026, 8, 4),
    );

    expect(options, hasLength(1));
    expect(options.single.startTime, '20:15');
  });

  test('8月29日のパーク全体公演を時刻順で取得できる', () async {
    final repository = LocalPerformanceScheduleRepository();
    final options = await repository.findParkOptions(
      parkId: 'tokyo_disneyland',
      date: DateTime(2026, 8, 29),
    );

    expect(options, isNotEmpty);
    expect(
      options.any(
        (option) =>
            option.facilityId ==
                'tdl_world_bazaar_electrical_parade_dreamlights' &&
            option.startTime == '19:45',
      ),
      isTrue,
    );
    expect(
      options.any(
        (option) =>
            option.facilityId ==
                'tdl_world_bazaar_reach_for_the_stars' &&
            option.startTime == '20:55',
      ),
      isTrue,
    );
  });

}
