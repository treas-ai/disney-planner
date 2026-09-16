import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全希望達成後は朝一を保持し予約なし食事を含む全日制約探索を一度だけ使う', () {
    final source =
        File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('_optimizeCoveredDayByUnifiedBeamSearch('));
    expect(source, contains('const beamWidth = 320;'));
    expect(source, contains("item.id.startsWith('fixed_restaurant_')"));
    expect(source, contains('item.type == ScheduleItemType.lunch'));
    expect(source, contains('item.type == ScheduleItemType.dinner'));
    expect(source, contains('final openingCommittedItem = items'));
    expect(
      source,
      contains('if (identical(item, openingCommittedItem)) return false;'),
    );
    expect(source, contains('slot += 10'));
    expect(source, contains('if (travelChecked != requestedStart) continue;'));
    expect(source, isNot(contains('maxSlotsPerFacility = 18')));
  });
}
