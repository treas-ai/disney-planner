# Historical wait input

公開待ち時間履歴を直接アプリへ埋め込まず、出典を確認したCSVまたはJSONをこの共通形式へ変換してから生成ツールへ渡します。

必須列: `parkId`, `facilityId`, `observedAt`, `waitMinutes`
任意列: `eventIds`（`|`区切り）, `isHoliday`, `isExcluded`, `exclusionReason`

実行例:

```powershell
dart run tool/generate_historical_wait_profiles.dart tokyo_disneyland data/tdl_wait.csv "公開データ名・URL・取得日"
```

利用規約、robots.txt、再配布条件を確認し、許可されていない自動取得やデータ同梱は行わないでください。
