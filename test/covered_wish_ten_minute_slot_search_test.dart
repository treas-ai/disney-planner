import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full coverage optimizer scans explicit ten minute wait slots', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();
    expect(source, contains('_optimizeCoveredWishTimingByTenMinuteSlots('));
    expect(source, contains('while (slot < exitMinutes)'));
    expect(source, contains('slot += 10;'));
    expect(source, contains('if (available != requestedStart) continue;'));
    expect(source, contains("id: 'slot_repack_\${facility.id}'"));
    expect(source, contains('waitProfileSpreadOpportunity'));
  });
}
