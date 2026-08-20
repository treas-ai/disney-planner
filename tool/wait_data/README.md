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

v7.4.4候補以降、以下のrawデータは **`live-data` ブランチ** に保存します。5分ごとのBot commitは `main` を更新しません。

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

収集履歴は既存の `HistoricalWaitDataImporter` / `HistoricalWaitProfileGenerator` 系へ接続します。`rebuild_github_wait_profiles.dart` は `--data-root` を受け取れるため、GitHub Actionsでは `.live-data/tool/wait_data` を入力として使用します。ローカルで引数を省略した場合は従来どおり `tool/wait_data` を読みます。

最終的に以下へ集約します。

- `assets/master/wait_profiles/<parkId>.json`
- `assets/master/crowd_factors/<parkId>.json`

次段階ではGitHub収集履歴からの集約経路と予測ロジックへの接続を重点確認します。

## Gitブランチ分離

v7.4.4候補では次の役割分担にします。

- `main`: アプリコード、設定、集約済み予測JSON
- `live-data`: 5分ごとのraw wait/DPA、unmatched、schedule diagnostics、月次archive

初回だけv7.4.4をmainへpush後に実行:

```powershell
.\setup_live_data_branch.ps1
```

`Collect TDR live data` は `main` をソースコードとしてcheckoutし、同時に `live-data` を `.live-data` へcheckoutします。Pythonツールの `DISNEY_PLANNER_WAIT_DATA_ROOT` を `.live-data/tool/wait_data` へ向けるため、最新コードを使いつつrawデータだけを安全に分離できます。

日次 `Rebuild TDR wait profiles` は `live-data` を読み、`assets/master/wait_profiles` と `crowd_factors` の集約結果だけを `main` へ反映します。

## クレジット

表示・予測にThemeParks.wikiデータを利用する場合、アプリ内の `Powered by ThemeParks.wiki` クレジットを維持します。

## Coverage audit (v7.4.6)

Run from the project root:

```powershell
python tool/audit_wait_profile_coverage.py --data-root tool/wait_data
```

In GitHub Actions the daily profile rebuild uses `.live-data/tool/wait_data`, so the report includes the raw live-data branch. The report is written to `docs/current/WAIT_PROFILE_COVERAGE_AUDIT.md`. The audit never invents facility mappings.

ThemeParks.wiki timestamps are UTC (`Z`). Wait profile time bands are Tokyo local time and therefore must be classified after conversion to JST (UTC+9).

`unmatched/<park>.txt` now represents only the unresolved entries from the latest collection run. If the latest run has zero unmatched entries, the old file is removed.
