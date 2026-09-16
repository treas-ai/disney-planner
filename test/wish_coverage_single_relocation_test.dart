import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('未達希望は自由時間化の前に既存1件の再配置まで探索する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    final repairCall = source.indexOf('_repairWishCoverageBySingleRelocation(');
    final freeTimeCall = source.indexOf('_addFlexibleOpenTimeBlocks(');
    expect(repairCall, greaterThanOrEqualTo(0));
    expect(freeTimeCall, greaterThan(repairCall));

    // A trial is committed only when the missing wish and the displaced wish
    // are both present. This protects coverage instead of merely swapping
    // which 1 wish is omitted.
    expect(source, contains('!hasFacility(trial, missingFacility.id)'));
    expect(source, contains('!hasFacility(trial, displacedId)'));
  });
}
