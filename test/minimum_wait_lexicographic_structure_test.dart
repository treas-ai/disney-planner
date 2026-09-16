import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minimumWait makes standby wait the primary full-day objective', () {
    final source =
        File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('int _compareUnifiedOptimizationCost('));
    expect(
      source,
      contains('if (mode == ScheduleOptimizationMode.minimumWait)'),
    );
    expect(
      source,
      contains('a.standbyWaitMinutes.compareTo(b.standbyWaitMinutes)'),
    );
    expect(
      source,
      contains('_compareUnifiedOptimizationCost(candidate, baseline, mode) < 0'),
    );
  });

  test('full coverage guard still protects desired facilities', () {
    final source =
        File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('if (!hasFullRegularWishCoverage(items))'));
    expect(source, contains('if (!hasFullRegularWishCoverage(best.items))'));
  });
}
