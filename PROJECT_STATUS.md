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
