import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('初回生成は待ち時間重視を基準にし、4モードは再生成時の調整に使う', () {
    final source =
        File('lib/features/plan_review/plan_review_screen.dart').readAsStringSync();
    expect(source, contains('var selectedMode = ScheduleOptimizationMode.minimumWait'));
    expect(source, contains('if (hasExistingPlan)'));
    expect(source, contains('プランを調整'));
    expect(source, contains('バランス重視'));
    expect(source, contains('待ち時間重視'));
    expect(source, contains('移動少なめ'));
    expect(source, contains('まとまった自由時間'));
    expect(source, contains('copyWith(scheduleOptimizationMode: selectedMode)'));
    expect(source, contains('この組み方で再生成'));
  });

  test('生成結果で通常待機と空き時間を提示して次の予定を促す', () {
    final source =
        File('lib/features/plan_review/plan_review_screen.dart').readAsStringSync();
    expect(source, contains('まず、やりたいことを待ち時間重視で組みました'));
    expect(source, contains('standbyWaitMinutes'));
    expect(source, contains('使える空き時間'));
    expect(source, contains('ほかにやりたいことはありますか？'));
    expect(source, contains('レストラン・休憩・追加施設'));
  });

  test('旅行設定にはプランの組み方を重複表示しない', () {
    final source =
        File('lib/features/settings/settings_screen.dart').readAsStringSync();
    expect(source, isNot(contains('_OptimizationModeSettingsCard')));
    expect(source, isNot(contains('プランの組み方')));
  });

  test('ライブデータ取得元は通常の旅行設定UIに表示しない', () {
    final source =
        File('lib/features/settings/settings_screen.dart').readAsStringSync();
    expect(source, isNot(contains('_LiveDataSourceSettingsCard')));
  });
}
