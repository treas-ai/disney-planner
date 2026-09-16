import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('通常配置でも一日難易度を使って高需要の未達希望を先に保護する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('final coverageDifficultyBonus ='));
    expect(source, contains('dayDifficultyMinutes.clamp(0, 150).toDouble() * 0.55'));
    expect(source, contains('score += coverageDifficultyBonus'));
    expect(source, isNot(contains("facility.name == '美女と野獣")));
  });
}
