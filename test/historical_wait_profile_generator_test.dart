import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/domain/entities/historical_wait_record.dart';
import 'package:disney_planner/domain/enums/wait_time_band.dart';
import 'package:disney_planner/domain/services/historical_wait_profile_generator.dart';

void main() {
  test('generates factor metadata and seven time bands', () {
    final records = List.generate(40, (index) => HistoricalWaitRecord(
      parkId: 'tokyo_disneyland',
      facilityId: 'ride_a',
      observedAt: DateTime(2026, 7, 1 + (index % 20), 9 + (index % 12)),
      waitMinutes: 20 + index,
      source: 'test',
      eventIds: const ['summer'],
      isHoliday: index.isEven,
    ));
    const generator = HistoricalWaitProfileGenerator();
    final result = generator.generate(parkId: 'tokyo_disneyland', records: records, calculatedAt: DateTime.utc(2026, 8, 5));
    expect(result.waitProfiles, hasLength(1));
    expect(result.waitProfiles.single.ranges.keys.toSet(), WaitTimeBand.values.toSet());
    expect(result.factors, isNotEmpty);
    expect(result.factors.every((item) => item.sampleCount > 0), isTrue);
    expect(result.factors.every((item) => item.methodVersion == '5.1.1'), isTrue);
  });

  test('ThemeParks.wiki UTC timestamps are classified using JST time bands', () {
    final records = <HistoricalWaitRecord>[
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 0, 30), // 09:30 JST
        waitMinutes: 10,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 2, 30), // 11:30 JST
        waitMinutes: 20,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 4, 0), // 13:00 JST
        waitMinutes: 30,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 6, 30), // 15:30 JST
        waitMinutes: 40,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 8, 30), // 17:30 JST
        waitMinutes: 50,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 10, 0), // 19:00 JST
        waitMinutes: 60,
        source: 'test',
      ),
      HistoricalWaitRecord(
        parkId: 'tokyo_disneyland',
        facilityId: 'ride_a',
        observedAt: DateTime.utc(2026, 8, 20, 11, 30), // 20:30 JST
        waitMinutes: 70,
        source: 'test',
      ),
    ];

    final result = const HistoricalWaitProfileGenerator().generate(
      parkId: 'tokyo_disneyland',
      records: records,
      calculatedAt: DateTime.utc(2026, 8, 20, 12),
    );
    final ranges = result.waitProfiles.single.ranges;
    expect(ranges[WaitTimeBand.afterOpening]!.typicalMinutes, 10);
    expect(ranges[WaitTimeBand.beforeLunch]!.typicalMinutes, 20);
    expect(ranges[WaitTimeBand.afterLunch]!.typicalMinutes, 30);
    expect(ranges[WaitTimeBand.aroundShows]!.typicalMinutes, 40);
    expect(ranges[WaitTimeBand.beforeDinner]!.typicalMinutes, 50);
    expect(ranges[WaitTimeBand.afterDinner]!.typicalMinutes, 60);
    expect(ranges[WaitTimeBand.beforeClosing]!.typicalMinutes, 70);
    for (final band in WaitTimeBand.values) {
      expect(ranges[band]!.sampleCount, 1);
    }
  });

}
