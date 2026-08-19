# Wait data collection

ThemeParks.wiki の公開 live API から TDL/TDS の待ち時間を収集し、Disney Planner の既存 `HistoricalWaitDataImporter` / `HistoricalWaitProfileGenerator` に集約します。

## 1回だけ取得

```powershell
.\collect_wait_data.ps1
```

## 開園中に5分間隔で継続取得

```powershell
.\collect_wait_data.ps1 -Continuous -IntervalMinutes 5
```

Ctrl+C で停止します。

## 24回（2時間）だけ取得

```powershell
.\collect_wait_data.ps1 -Count 24 -IntervalMinutes 5
```

取得履歴:
- `tool/wait_data/history/tokyo_disneyland.csv`
- `tool/wait_data/history/tokyo_disneysea.csv`

生スナップショット:
- `tool/wait_data/raw/<parkId>/...json`

集約結果:
- `assets/master/wait_profiles/<parkId>.json`
- `assets/master/crowd_factors/<parkId>.json`

API側は数分単位で更新されるため、5分未満では取得しません。
`unmatched_*.txt` が生成された場合は、ThemeParks.wiki名とDisney Planner施設IDのalias追加が必要です。

表示・予測にThemeParks.wikiデータを利用するため、アプリ内に `Powered by ThemeParks.wiki` のクレジットを表示します。

## GitHub Actions 自動収集

`.github/workflows/collect-tdr-live-data.yml` は 08:07〜22:57 JST の間、10分間隔で起動し、FlutterをセットアップせずPython標準ライブラリだけで軽量収集します。

保存先:
- 待ち時間: `tool/wait_data/github_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- DPA状態: `tool/wait_data/dpa_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- 未マッピング施設: `tool/wait_data/unmatched/<parkId>.txt`

`.github/workflows/rebuild-tdr-wait-profiles.yml` は毎日23:35 JSTにFlutterを使って蓄積履歴を集約し、`assets/master/wait_profiles/` と `assets/master/crowd_factors/` を更新します。

GitHub Actionsの `schedule` は厳密な実行時刻を保証しないため、観測時刻はAPIの `lastUpdated` を使用します。収集が一部遅延・欠落しても、次回観測で継続します。
