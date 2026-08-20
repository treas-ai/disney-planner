# ThemeParks.wiki unmatched fix

更新日: 2026-08-20  
関連タグ: **v7.4.2**

## マッピング方式

`tool/github_collect_themeparks_wiki.py` は次の順でDisney Planner施設IDを解決します。

1. `sourceEntityAliases` のThemeParks.wiki UUID
2. `aliases` の正規化施設名

名前の正規化は小文字化、`&` → `and`、英数字以外の除去です。

## 対応済み

- Westernland Shootin' Gallery
  - `tdl_westernland_shooting_gallery`
- DisneySea Electric Railway (American Waterfront)
  - `tds_aw_a_004`
- DisneySea Electric Railway (Port Discovery)
  - `tds_pd_a_003`
- Anna and Elsa's Frozen Journey
  - `tds_fs_a_001`

## v7.4.2修正

### Frozen Journey

ThemeParks.wiki名 `Anna and Elsa's Frozen Journey` の正規化結果は:

```text
annaandelsasfrozenjourney
```

設定側が `annandelsasfrozenjourney` となっていたため一致せず、unmatchedになっていました。v7.4.2で正しいキーへ修正しました。

### DisneySea Electric Railway (Port Discovery)

ThemeParks.wiki UUIDを次へ修正しました。

```text
c8744918-42c0-427d-8947-c3dbd1abf8d5
```

## Transit Steamer Line

現在のDisney Planner施設マスターには以下のThemeParks.wikiエンティティに対応する独立施設IDがないため、架空の内部IDは作成しません。

- DisneySea Transit Steamer Line (American Waterfront)
- DisneySea Transit Steamer Line (Lost River Delta)

これらは `ignoredSourceEntityIds` で明示的に除外します。将来、施設マスターへ正式追加した場合はignoreを解除し、正しい `sourceEntityAliases` を追加します。

## 次回確認

v7.4.2反映後に `Collect TDR live data` を実行し、最新実行でTDSのunmatchedが解消しているか確認します。

注意: `tool/wait_data/unmatched/*.txt` は過去に検出した値を集合として保持するため、設定修正後も古い行が自動削除されるとは限りません。判定は最新Actionsログと新規観測CSVを優先します。
