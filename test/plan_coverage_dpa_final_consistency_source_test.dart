import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DPA推奨は最終プランで未達成の希望だけを対象にする', () {
    final source = File(
      'lib/domain/services/plan_coverage_advice_service.dart',
    ).readAsStringSync();
    expect(source, contains('final unmetIds ='));
    expect(source, contains('if (!unmetIds.contains(metric.facilityId)) continue;'));
    expect(source, contains('!facility.supportsDpa'));
  });
}
