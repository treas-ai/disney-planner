import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/today/today_access_input_screen.dart',
  ).readAsStringSync();

  test('当日取得状況は3セクションに分ける', () {
    expect(source, contains("title: 'アトラクション'"));
    expect(source, contains("title: 'ショー・パレード'"));
    expect(source, contains("title: 'モバイルオーダー'"));
  });

  test('DPAは事前予定外もパーク全体から候補にする', () {
    expect(source, contains('for (final facility in _parkFacilities)'));
    expect(source, contains('if (!facility.supportsDpa) continue;'));
    expect(source, contains('TodayAccessKind.attractionDpa'));
    expect(source, contains('TodayAccessKind.showDpa'));
  });

  test('同じ施設のDPAと抽選は1枚の施設カードへまとめる', () {
    expect(source, contains("grouped.putIfAbsent(candidate.facility.id"));
    expect(source, contains('_FacilityAccessCard('));
    expect(source, contains('_AccessKindRow('));
  });

  test('未入力は取得していないを既定表示にする', () {
    expect(source, contains("? '取得していない'"));
    expect(source, contains('実際に取得・当選・落選などがあった項目だけ入力'));
  });
}
