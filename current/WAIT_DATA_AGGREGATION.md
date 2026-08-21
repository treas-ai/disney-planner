# Wait Data Aggregation

Disney Planner の待ち時間データを1回限りのシードではなく、継続観測データへ移行する。

## Source
ThemeParks.wiki public API
- TDL park entity: `3cc919f1-d16d-43e0-8c3f-1dd269bd1a42`
- TDS park entity: `67b290d5-3478-4f23-b601-2f8fb71ba803`
- live endpoint: `/v1/entity/<parkEntityId>/live`

## Collection
`collect_wait_data.ps1` が5分以上の間隔で live snapshot を取得する。

保存:
- raw JSON: `tool/wait_data/raw/`
- normalized CSV: `tool/wait_data/history/`

CSVは既存 `HistoricalWaitDataImporter` 形式なので、収集後そのまま `HistoricalWaitProfileGenerator` へ集約する。

## App runtime
`OfficialLiveDataProvider` も同じAPIを使用し、現在のStandby wait / status / paid return stateをToday側へ提供する。
取得不能時は既存CachedLiveDataProviderがmockへfallbackする。

## Mapping
ThemeParks.wikiは英語名、Disney Plannerは日本語マスターのため、
`assets/master/live_mapping/themeparks_wiki_tokyo.json` でaliasを管理する。
未一致はcollectorが `unmatched_<park>.txt` に出力する。

## Fair use
APIは数分ごとに更新されるため、5分未満のpollingをしない。
アプリ内に `Powered by ThemeParks.wiki` を表示する。
