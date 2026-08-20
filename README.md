# Disney Planner

**公式アプリと一緒に使うAIディズニープランナー**

Disney Plannerはディズニー公式アプリの代替ではありません。チケット、予約、公式待ち時間、公式マップなどは公式アプリで確認し、本アプリは事前計画、当日のスケジュール管理、再計算、待ち時間履歴の活用、AIによる候補評価を補助します。

## 現在の開発状態

- 現在の安定タグ: **v7.4.2**
- `flutter analyze --no-pub`: **No issues found!**（直近確認）
- `flutter test --no-pub`: **All tests passed!**（直近確認）
- TDL/TDS待ち時間・DPA状態の自動収集基盤: **稼働開始**
- ThemeParks.wiki施設マッピング: v7.4.2でTDSの追加修正

詳細は `docs/current/PROJECT_STATUS.md` と `docs/current/ROADMAP.md` を参照してください。

## 現在の主な機能

- 旅行設定 → Wish List → 候補確認 → プラン生成の計画フロー
- TDL/TDS施設検索・絞り込み
- 固定予定、予約、DPA/PP等を考慮したスケジュール生成
- Today画面と残り予定の再計算・比較・承認・Undo
- 運営状況・来園日ベースの休止判定
- 移動時間エンジン
- 待ち時間履歴・AI学習データ基盤
- 待ち時間予測と動的スコアリング基盤
- AIプラン最適化・リアルタイム再計画基盤
- ローカル共有・履歴基盤

## TDRライブデータ収集

ThemeParks.wiki の公開live APIから、東京ディズニーランド／東京ディズニーシーの待ち時間とDPA状態を収集します。

現在は GitHub Actions の `workflow_dispatch` を外部スケジューラから起動し、**JST 08:00〜21:55を5分間隔、22:00に最終1回**の収集を行う構成です。GitHub Actions標準のscheduled実行は遅延が大きかったため、5分周期の主トリガーには使用しません。

保存先:

- 待ち時間: `tool/wait_data/github_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- DPA状態: `tool/wait_data/dpa_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- 未マッピング: `tool/wait_data/unmatched/<parkId>.txt`
- スケジュール診断: `tool/wait_data/schedule_diagnostics.csv`

施設対応表は `assets/master/live_mapping/themeparks_wiki_tokyo.json` です。v7.4.2では `Anna and Elsa's Frozen Journey` と DisneySea Electric Railway (Port Discovery) のマッピングを修正しました。

詳しくは `tool/wait_data/README.md` と `docs/current/THEMEPARKS_WIKI_UNMATCHED_FIX.md` を参照してください。

## 待ち時間データの利用方針

収集した履歴は、将来的な待ち時間予測・朝一候補評価・動的スケジュール最適化の入力に使用します。予測値は公式情報ではなく、公式アプリの確認を前提とした参考値として扱います。

次の重点は、**収集品質の監視 → unmatched解消確認 → 履歴集約 → 予測ロジックへの安定接続**です。

## 開発環境

通常確認:

```powershell
.\verify.ps1
```

個別確認:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run --no-pub -d windows
```

依存関係を変更した場合のみ、必要に応じて `flutter pub get` を実行します。

## マスターデータ監査

```powershell
dart run tool/audit_master_data.dart
```

監査結果は `docs/audits/MASTER_DATA_AUDIT_REPORT.md` に出力します。

## Git運用

自動収集Botが `main` に観測データをコミットするため、ローカルpush時に `fetch first` が発生することがあります。その場合は強制pushせず、次を使用します。

```powershell
git pull --rebase origin main
git push origin main
```

リリースタグ例:

```powershell
git tag -a vX.X.X -m "vX.X.X <summary>"
git push origin vX.X.X
```

今後は、開発用 `main` と自動収集データの競合を減らすため、収集データの保存ブランチ／保存方式の分離を検討します。

## 外部サービスと注意事項

- ThemeParks.wiki: ライブデータ取得元。アプリ表示時はクレジットを維持します。
- cron-job.org: 5分周期の外部トリガーとして利用中。
- GitHub PAT等の秘密情報はリポジトリ、README、スクリーンショット、チャットへ貼り付けません。
- 公式情報は必ずディズニー公式アプリ／公式サイトを優先します。
