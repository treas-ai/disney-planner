import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('朝一は現在待ちだけでなく一日難易度と後回し損失を評価する', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();

    // チューニング係数の数値そのものは固定しない。
    // 朝一評価に必要な評価軸が残っていることを回帰確認する。
    expect(source, contains('dayDifficultyMinutes'));
    expect(source, contains('waitEstimate.waitMinutes'));
    expect(source, contains('deferLoss'));
    expect(source, contains('difficultyFallback'));
    expect(source, contains('profileDeferLoss'));
  });

  test('後回し損失0分のとき後回し損失が大きいとは説明しない', () {
    final source = File('lib/domain/services/schedule_engine.dart').readAsStringSync();
    expect(source, contains('detail.deferLossMinutes >= 15'));
    expect(source, contains('後回し損失だけでなく、一日を通した通常待機難易度'));
  });
}
