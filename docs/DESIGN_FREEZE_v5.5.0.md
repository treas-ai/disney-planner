# Disney Planner v5.5.0 設計凍結書

## 凍結日
2026-08-05

## 目的
v5.1.1までに実装済みの待ち時間履歴、混雑係数、時間帯別待ち時間、Wish候補評価、DPA自動割当、Schedule Engineを、単一のAIプラン生成フローへ接続する。

## 凍結した構成
- 既存のdomain/data/features構成は維持する。
- 大規模なファイル移動や既存API破壊は行わない。
- `lib/ai/planner/ai_day_planner.dart`を上位オーケストレーターとする。
- AI処理順序は以下で固定する。
  1. 滞在可能時間算出
  2. Wish候補採点
  3. 実行可能件数への絞り込み
  4. DPA自動割当
  5. Schedule Engine生成
  6. Today表示用理由を既存ScheduleItem.reasonへ保持
- 5分単位の時刻処理、既存の固定予定優先、レストラン・ショー処理はSchedule Engineに委譲する。
- 公開待ち時間データはCSV/JSONインポート方式を維持し、特定サイトへの直接スクレイピング依存を追加しない。

## 軽量化方針
- `build/`、`.dart_tool/`、`.git/`、各プラットフォームのephemeralを配布ZIPへ含めない。
- 起動時の全履歴再計算を行わず、生成済みプロファイルを使用する。
- 既存モデルの重複コピーを作らない。

## 追加ファイル
- `lib/ai/planner/ai_day_planner.dart`
- `lib/domain/entities/ai_plan_result.dart`
- `test/ai_day_planner_test.dart`

## 非対象
- 機械学習モデルの端末内学習
- 公式アプリの待ち時間取得
- 地図・メニュー・施設詳細の複製
- 海外パーク固有データ

## 完了条件
- flutter analyze: No issues found!
- flutter test: All tests passed!
- verify.ps1: Errors: 0
