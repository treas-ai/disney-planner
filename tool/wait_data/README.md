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
