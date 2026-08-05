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
}
