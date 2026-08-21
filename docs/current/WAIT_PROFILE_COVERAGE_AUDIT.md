# Wait Profile Coverage Audit

Generated: 2026-08-22T00:06:51+09:00

This report does not invent facility IDs. Mapping issues are reported for manual verification.

## tokyo_disneyland

- Active master attractions: 33
- Mapped active attractions: 33
- Generated profiles: 28
- Profile source observations: 1302

### 1. Profile missing facilities

- `tdl_adventureland_western_river_railroad` — ウエスタンリバー鉄道; raw observations=0
- `tdl_fantasyland_castle_carrousel` — キャッスルカルーセル; raw observations=0
- `tdl_fantasyland_haunted_mansion` — ホーンテッドマンション; raw observations=0
- `tdl_fantasyland_poohs_hunny_hunt` — プーさんのハニーハント; raw observations=0
- `tdl_toontown_toon_park` — トゥーンパーク; raw observations=0
- `tdl_world_bazaar_penny_arcade` — ペニーアーケード; raw observations=0

### 2. Time-band coverage

- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_fantasyland_alices_tea_party` — アリスのティーパーティー: no usable samples in 閉園前
- `tdl_fantasyland_cinderella_fairy_tale_hall` — シンデレラのフェアリーテイル・ホール: no usable samples in 閉園前
- `tdl_fantasyland_its_a_small_world` — イッツ・ア・スモールワールド: no usable samples in 閉園前
- `tdl_fantasyland_mickeys_philharmagic` — ミッキーのフィルハーマジック: no usable samples in 閉園前
- `tdl_fantasyland_pinocchios_daring_journey` — ピノキオの冒険旅行: no usable samples in 閉園前
- `tdl_tomorrowland_stitch_encounter` — スティッチ・エンカウンター: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_toontown_chip_and_dales_treehouse` — チップとデールのツリーハウス: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_toontown_donalds_boat` — ドナルドのボート: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_toontown_goofys_paint_and_play_house` — グーフィーのペイント＆プレイハウス: no usable samples in 閉園前
- `tdl_toontown_minnies_house` — ミニーの家: no usable samples in 昼前, 昼過ぎ, 夕食後, 閉園前
- `tdl_westernland_country_bear_theater` — カントリーベア・シアター: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 閉園前
- `tdl_westernland_mark_twain_riverboat` — 蒸気船マークトウェイン号: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_westernland_shooting_gallery` — ウエスタンランド・シューティングギャラリー: no usable samples in 閉園前
- `tdl_westernland_tom_sawyer_island_rafts` — トムソーヤ島いかだ: no usable samples in 開園直後, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_world_bazaar_omnibus` — オムニバス: no usable samples in 昼前, 夕食前, 夕食後, 閉園前

### 2b. Low-confidence time bands (<3 samples)

- `tdl_adventureland_jungle_cruise` — ジャングルクルーズ：ワイルドライフ・エクスペディション: 昼前 = 2 samples
- `tdl_fantasyland_cinderella_fairy_tale_hall` — シンデレラのフェアリーテイル・ホール: 昼前 = 2 samples
- `tdl_fantasyland_cinderella_fairy_tale_hall` — シンデレラのフェアリーテイル・ホール: 夕食後 = 2 samples
- `tdl_fantasyland_mickeys_philharmagic` — ミッキーのフィルハーマジック: 昼前 = 1 samples
- `tdl_fantasyland_mickeys_philharmagic` — ミッキーのフィルハーマジック: 夕食前 = 1 samples
- `tdl_fantasyland_peter_pans_flight` — ピーターパン空の旅: 昼前 = 2 samples
- `tdl_fantasyland_peter_pans_flight` — ピーターパン空の旅: 閉園前 = 2 samples
- `tdl_fantasyland_pinocchios_daring_journey` — ピノキオの冒険旅行: 昼前 = 2 samples
- `tdl_tomorrowland_baymax_happy_ride` — ベイマックスのハッピーライド: 閉園前 = 1 samples
- `tdl_toontown_goofys_paint_and_play_house` — グーフィーのペイント＆プレイハウス: 夕食前 = 2 samples
- `tdl_toontown_minnies_house` — ミニーの家: ショー前後 = 1 samples
- `tdl_toontown_minnies_house` — ミニーの家: 夕食前 = 1 samples
- `tdl_westernland_country_bear_theater` — カントリーベア・シアター: 夕食後 = 1 samples

### 3. Facility-ID mapping audit

- All mapping targets exist in master facility data.
- No currently actionable unmatched entries in the available unmatched file.

## tokyo_disneysea

- Active master attractions: 27
- Mapped active attractions: 27
- Generated profiles: 25
- Profile source observations: 1598

### 1. Profile missing facilities

- `tds_mh_a_002` — フォートレス・エクスプロレーション; raw observations=0
- `tds_ml_a_001` — アリエルのプレイグラウンド; raw observations=0
- `tds_ml_a_004` — フランダーのフライングフィッシュコースター; raw observations=0

### 2. Time-band coverage

- `tds_ac_a_003` — シンドバッド・ストーリーブック・ヴォヤッジ: no usable samples in 閉園前
- `tds_ac_a_004` — マジックランプシアター: no usable samples in 昼前, ショー前後, 夕食前, 閉園前
- `tds_aw_a_005` — ビッグシティ・ヴィークル: no usable samples in 開園直後, 昼前, 昼過ぎ, 夕食前
- `tds_mh_a_001` — ヴェネツィアン・ゴンドラ: no usable samples in 開園直後, 昼前, 昼過ぎ, 閉園前
- `tds_ml_a_003` — スカットルのスクーター: no usable samples in 閉園前
- `tds_ml_a_007` — ワールプール: no usable samples in 閉園前
- `tds_pd_a_002` — ニモ＆フレンズ・シーライダー: no usable samples in 閉園前
- `tds_pd_a_003` — ディズニーシー・エレクトリックレールウェイ（ポートディスカバリー）: no usable samples in 昼前

### 2b. Low-confidence time bands (<3 samples)

- `tds_ac_a_001` — キャラバンカルーセル: 昼前 = 1 samples
- `tds_ac_a_001` — キャラバンカルーセル: 閉園前 = 1 samples
- `tds_ac_a_003` — シンドバッド・ストーリーブック・ヴォヤッジ: 昼前 = 1 samples
- `tds_ac_a_003` — シンドバッド・ストーリーブック・ヴォヤッジ: 夕食前 = 2 samples
- `tds_ac_a_003` — シンドバッド・ストーリーブック・ヴォヤッジ: 夕食後 = 1 samples
- `tds_ac_a_004` — マジックランプシアター: 昼過ぎ = 2 samples
- `tds_ac_a_004` — マジックランプシアター: 夕食後 = 2 samples
- `tds_aw_a_005` — ビッグシティ・ヴィークル: 閉園前 = 2 samples
- `tds_fs_a_003` — ピーターパンのネバーランドアドベンチャー: 昼前 = 2 samples
- `tds_mh_a_001` — ヴェネツィアン・ゴンドラ: 夕食後 = 1 samples
- `tds_mi_a_001` — 海底2万マイル: 閉園前 = 2 samples
- `tds_mi_a_002` — センター・オブ・ジ・アース: 昼前 = 1 samples
- `tds_ml_a_002` — ジャンピン・ジェリーフィッシュ: 閉園前 = 1 samples
- `tds_ml_a_005` — ブローフィッシュ・バルーンレース: 閉園前 = 1 samples
- `tds_pd_a_001` — アクアトピア: 夕食前 = 2 samples

### 3. Facility-ID mapping audit

- All mapping targets exist in master facility data.
- No currently actionable unmatched entries in the available unmatched file.

## Interpretation

- A 0/0/0 range is treated as unavailable by the scheduling engine and is therefore reported as missing coverage.
- v7.4.8 stores sampleCount per time band; nearest-band fallback requires at least 3 samples. Direct-band observations remain usable even when thin, but the source text exposes the exact band sample count.
- ThemeParks.wiki timestamps are UTC; time-band coverage must be classified after conversion to JST.
- An active master attraction without mapping is not automatically an error; some source entities do not expose a standby wait queue.

