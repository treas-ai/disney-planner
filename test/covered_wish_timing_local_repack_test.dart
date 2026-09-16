import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('10/10達成後は旧局所再配置ではなく朝一を保持した全日統合探索を使う', () {
    final source =
        File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    final repairIndex =
        source.indexOf('_repairWishCoverageBySingleRelocation(');
    final unifiedIndex =
        source.indexOf('_optimizeCoveredDayByUnifiedBeamSearch(');
    final freeTimeIndex = source.indexOf('_addFlexibleOpenTimeBlocks(');

    expect(repairIndex, greaterThanOrEqualTo(0));
    expect(unifiedIndex, greaterThan(repairIndex));
    expect(freeTimeIndex, greaterThan(unifiedIndex));
    expect(source, contains('final openingCommittedItem = items'));
    expect(
      source,
      contains('if (identical(item, openingCommittedItem)) return false;'),
    );
    expect(source, contains('const beamWidth = 320;'));
    expect(source, contains('if (travelChecked != requestedStart) continue;'));
  });
}
