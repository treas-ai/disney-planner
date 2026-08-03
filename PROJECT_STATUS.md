# Disney Planner — PROJECT_STATUS

更新日: 2026-08-03
対象バージョン: v2.5 開発中
開発環境: Flutter / Windows / Git / GitHub / SharedPreferences

## コンセプト

公式アプリを置き換えず、一緒に使うAIディズニープランナー。

## v2.4までの主な完成項目

- 施設検索
- プラン編集
- 固定予定
- スケジュール生成
- Plan Review
- Today
- リアルタイムデータRepository基盤
- 残り予定再計算
- Before / After比較
- 承認後反映
- 1世代Undo

## v2.5で追加

- FacilityLocation
- AreaConnection
- MovementEstimate
- MovementRepository
- LocalMovementRepository
- ApiMovementRepository雛形
- MovementTimeEngine
- ローカル移動時間マスター
- AI中心ROADMAPへの再編

## v2.5の制限

- 公式地図画像なし
- GPSなし
- 外部地図SDKなし
- 初期移動マスターは空
- TodayとSchedule Engineへの本格UI統合は、確認済み移動データ投入後に行う

## 完了確認

```powershell
flutter pub get
dart format lib
flutter analyze
flutter run -d windows
```


## v2.6 追加内容

- 行動履歴共通モデル
- 待ち時間履歴の自動保存
- HistoryRepository / LocalHistoryRepository
- データ品質・取得元の識別
- LearningEngine基盤
- AI予測値を学習対象から除外する設計

## v2.7 実装内容

- AI待ち時間予測のDomain Interface
- 現在値と履歴を用いるルールベース予測
- 30分後・60分後・120分後の予測
- 予測範囲、信頼度、根拠
- Today画面への予測表示
- AI予測と公式待ち時間の明確な区別
## v2.8
- AIプラン評価・改善提案を実装
- 承認後反映と固定予定保護に対応
