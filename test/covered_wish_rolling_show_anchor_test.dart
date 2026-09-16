import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('10/10再配置は当日追加されたショー固定枠を保持して3手先まで比較する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('_coveredWishFixedAnchorFingerprint('));
    expect(source, contains('fixedAnchorFingerprint'));
    expect(source, contains('maxCrossAnchorTripleSetsPerRound = 60'));
    expect(source, contains('[first, second, third]'));
    expect(source, contains('[third, second, first]'));
    expect(source, contains('refill(List<ScheduleItem>.of(tripleBase), order);'));
    // 固定アンカーの生成方法を、Dart formatter の改行位置に依存せず検証する。
    expect(source, contains("'fixed_performance_'"));
    expect(source, contains("'fixed_access_\${facility.id}'"));
  });
}
