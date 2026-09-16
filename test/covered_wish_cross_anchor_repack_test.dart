import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('10/10再配置は固定アンカーを動かさず非連続3施設も再パック候補にする', () {
    final source =
        File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    expect(source, contains('maxCrossAnchorTripleSetsPerRound = 60'));
    expect(source, contains('for (var j = i + 1;'));
    expect(source, contains('for (var k = j + 1;'));
    expect(source, contains('..remove(movable[j])'));
    expect(source, contains('..remove(movable[k])'));
    expect(source, contains('_coveredWishFixedAnchorFingerprint('));
    expect(source, contains('fixedAnchorFingerprint'));
  });
}
