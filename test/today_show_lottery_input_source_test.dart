import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('当日取得状況画面はショー抽選結果を扱える', () {
    final source = File(
      'lib/features/today/today_access_input_screen.dart',
    ).readAsStringSync();

    // 実装上の候補生成方法には依存せず、抽選結果入力に必要な経路を確認する。
    expect(source, contains('TodayAccessKind.entryRequest'));
    expect(source, contains('TodayAccessStatus.won'));
    expect(source, contains('TodayAccessStatus.lost'));
    expect(source, contains('TodayAccessStatus.skipped'));
  });

  test('ショーDPAと抽選当選は当日の公演回から選択する', () {
    final source = File(
      'lib/features/today/today_access_input_screen.dart',
    ).readAsStringSync();

    expect(source, contains('TodayAccessKind.showDpa'));
    expect(source, contains('TodayAccessKind.entryRequest'));
    expect(source, contains('_loadPerformanceOptions()'));
    expect(source, contains('エントリー受付は当日の公演回から選択します'));
    expect(source, contains('ショー・パレードDPAは当日の公演回から選択します'));
  });
}
