# Disney Planner — PROJECT_STATUS

更新日: 2026-08-03
対象バージョン: v3.0 開発中

## 現在
- v2.9 AIコンシェルジュ完了
- v3.0でTDL/TDSマスターデータを再編
- TDS 8エリアと主要施設データを追加
- 変動情報は公式アプリ確認を前提

## 品質確認
- `flutter analyze`
- TDL/TDS切替
- マスターデータ検証
## v3.2

Park Intelligence / Event Impact Engineを実装。イベント影響マスターは確認済み情報だけを登録する。
## v3.3

AIコンシェルジュへ判断優先度・信頼度・スコアを追加。

## v3.3.2 Git Maintenance

- ルート`.gitignore`整備
- Flutter生成ファイルのGit追跡解除
- `git add .`を使える標準運用へ移行
- アプリ機能変更なし

## v3.4 Data Quality

- マスターデータ監査基盤実装
- TDL/TDS件数集計対応
- 公式URL・メニュー・休止確認日監査対応
- 正式版1.0.0に向けた不足項目の可視化

## v3.5 Live Operation Foundation

- ライブ運営情報のDomainモデルを追加
- LiveOperationRepositoryを追加
- Mock Repositoryで通信差し替え基盤を構築
- AIコンシェルジュへパーク状況カードを追加
- Mockデータと公式情報を明確に区別
## v3.7 Official Data Service Foundation

- Provider抽象化
- Mock／Official切替
- キャッシュ・フォールバック
- 外部接続はv3.8以降で判断
## v3.8 Manual Live Data Input

- 手動待ち時間入力
- 保存・復元
- 鮮度警告・前回差分
- Smart Schedule Engine連携
## v3.11 Release Readiness Pack

- Plan Safety & History
- Field Mode
- Backup & Restore
- Onboarding
- Data freshness display

