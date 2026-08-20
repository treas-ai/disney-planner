# Wait data collection

ThemeParks.wiki の公開live APIからTDL/TDSの待ち時間・DPA状態を収集し、Disney Plannerの待ち時間履歴・予測基盤へ接続します。

## ローカルで1回取得

```powershell
.\collect_wait_data.ps1
```

## ローカルで5分間隔取得

```powershell
.\collect_wait_data.ps1 -Continuous -IntervalMinutes 5
```

Ctrl+Cで停止します。

## GitHub Actions自動収集

軽量コレクタ:

```text
tool/github_collect_themeparks_wiki.py
```

Workflow:

```text
.github/workflows/collect-tdr-live-data.yml
```

GitHub Actions標準のscheduled実行は実運用で大きな遅延が確認されたため、現在の5分周期は **cron-job.org → GitHub workflow_dispatch** で起動します。

実運用スケジュール（JST）:

- 08:00〜21:55: 5分間隔
- 22:00: 最終1回

GitHub PATは外部スケジューラ側の認証情報としてのみ保持し、リポジトリへ保存しません。

## GitHub収集データ

- 待ち時間: `tool/wait_data/github_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- DPA状態: `tool/wait_data/dpa_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- 未マッピング施設: `tool/wait_data/unmatched/<parkId>.txt`
- 実行診断: `tool/wait_data/schedule_diagnostics.csv`

観測時刻にはAPIの `lastUpdated` を優先して使用します。起動が遅延しても、実際の観測時刻とActions開始時刻を混同しない設計です。

## 施設マッピング

設定:

```text
assets/master/live_mapping/themeparks_wiki_tokyo.json
```

解決順:

1. ThemeParks.wiki UUID (`sourceEntityAliases`)
2. 正規化施設名 (`aliases`)

v7.4.2で以下を修正済みです。

- Anna and Elsa's Frozen Journey → `tds_fs_a_001`
- DisneySea Electric Railway (Port Discovery) UUID

`unmatched/<parkId>.txt` は過去の検出値を保持するため、修正後も古い行が残る場合があります。最新のActionsログとCSVへの新規保存結果で現在のマッピング成否を確認してください。

## 履歴の集約

収集履歴は既存の `HistoricalWaitDataImporter` / `HistoricalWaitProfileGenerator` 系へ接続し、最終的に以下へ集約する方針です。

- `assets/master/wait_profiles/<parkId>.json`
- `assets/master/crowd_factors/<parkId>.json`

次段階ではGitHub収集履歴からの集約経路と予測ロジックへの接続を重点確認します。

## Git競合について

自動収集Workflowが `main` に観測データをcommitするため、ローカルpushと競合する場合があります。

```powershell
git pull --rebase origin main
git push origin main
```

強制pushは使用しません。将来的には収集データ専用ブランチ等への分離を検討します。

## クレジット

表示・予測にThemeParks.wikiデータを利用する場合、アプリ内の `Powered by ThemeParks.wiki` クレジットを維持します。
