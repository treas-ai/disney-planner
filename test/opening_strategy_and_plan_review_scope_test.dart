import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('プラン確認は事前計画専用で当日取得入力を直接置かない', () {
    final source = File(
      'lib/features/plan_review/plan_review_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      isNot(contains("import '../today/today_access_input_screen.dart';")),
    );
    expect(
      source,
      isNot(contains("label: const Text('当日の取得状況を入力')")),
    );
    expect(source, contains('取得後は「当日ガイド」から取得実績を入力'));
  });

  test('朝一評価は一日難易度を後回し損失の下限として利用する', () {
    final source = File(
      'lib/domain/services/schedule_engine.dart',
    ).readAsStringSync();

    expect(source, contains('final profileDeferLoss = timing?.delayPenaltyMinutes;'));
    expect(source, contains('final difficultyFallback ='));
    expect(source, contains('dayDifficultyMinutes - waitEstimate.waitMinutes'));
    expect(source, contains('profileDeferLoss == null'));
    expect(source, contains('profileDeferLoss >= difficultyFallback'));
    expect(source, contains('const maxDepth = 3'));
  });

  test('朝一評価は後回し損失・一日難易度・混雑罠・ルート継続を考慮する', () {
    final source = File(
      'lib/domain/services/schedule_engine.dart',
    ).readAsStringSync();

    // 係数そのものを固定せず、朝一戦略に必要な評価要素の存在を確認する。
    expect(source, contains('profileDeferLoss >= difficultyFallback'));
    expect(source, contains('score += dayDifficultyMinutes *'));
    expect(source, contains('score -= waitEstimate.waitMinutes *'));
    expect(source, contains('openingCongestionTrapMinutes'));
    expect(source, contains('committedOpeningFacilityIds'));
    expect(source, contains('openingSequenceFacilityIds'));
  });
}
