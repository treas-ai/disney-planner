import 'package:flutter_test/flutter_test.dart';
import 'package:disney_planner/data/importers/historical_wait_data_importer.dart';

void main() {
  test('imports valid CSV and reports invalid rows', () {
    const importer = HistoricalWaitDataImporter();
    final result = importer.importCsv(
      'parkId,facilityId,observedAt,waitMinutes,eventIds,isHoliday\n'
      'tokyo_disneyland,ride_a,2026-01-01T10:00:00+09:00,60,new_year,true\n'
      'tokyo_disneyland,ride_b,invalid,30,,false',
      source: 'test',
    );
    expect(result.records, hasLength(1));
    expect(result.errors, hasLength(1));
    expect(result.records.single.eventIds, ['new_year']);
    expect(result.records.single.isHoliday, isTrue);
  });
}
