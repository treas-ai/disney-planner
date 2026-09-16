import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('予約なし昼夕食は12時18時固定ではなく10分刻み可動枠を探索する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('_selectFlexibleMealStart'));
    expect(source, contains('MealSlot.lunch => (_toMinutes(11, 0), _toMinutes(14, 0)'));
    expect(source, contains('MealSlot.dinner => (_toMinutes(17, 0), _toMinutes(20, 0)'));
    expect(source, contains('candidate += 10'));
    expect(source, contains('peakPenalty'));
    expect(source, contains('flexibleMealTimeOptimized'));
    expect(source, contains('usedReservationTime: true'));
  });
}
