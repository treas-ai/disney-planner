# Wait Profile Coverage Audit

Generated: 2026-09-11T02:50:30+09:00

This report does not invent facility IDs. Mapping issues are reported for manual verification.

## tokyo_disneyland

- Active master attractions/greetings: 37
- Mapped active attractions: 37
- Generated profiles: 31
- Profile source observations: 14045

### 1. Profile missing facilities

- `tdl_fantasyland_haunted_mansion` — ホーンテッドマンション; raw observations=0
- `tdl_toontown_mickey_house_meet_mickey` — ミッキーの家とミート・ミッキー; raw observations=0
- `tdl_toontown_minnies_style_studio` — ミニーのスタイルスタジオ; raw observations=0
- `tdl_toontown_toon_park` — トゥーンパーク; raw observations=0
- `tdl_westernland_woodchuck_greeting_daisy` — ウッドチャック・グリーティングトレイル（デイジー）; raw observations=0
- `tdl_westernland_woodchuck_greeting_donald` — ウッドチャック・グリーティングトレイル（ドナルド）; raw observations=0
- `tdl_world_bazaar_penny_arcade` — ペニーアーケード; raw observations=0

### 2. Time-band coverage

- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: no usable samples in 夕食前
- `tdl_fantasyland_cinderella_fairy_tale_hall` — シンデレラのフェアリーテイル・ホール: no usable samples in 閉園前
- `tdl_tomorrowland_stitch_encounter` — スティッチ・エンカウンター: no usable samples in 昼前, 閉園前
- `tdl_toontown_chip_and_dales_treehouse` — チップとデールのツリーハウス: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 閉園前
- `tdl_toontown_donalds_boat` — ドナルドのボート: no usable samples in 昼前, 昼過ぎ, ショー前後, 夕食前, 閉園前
- `tdl_toontown_goofys_paint_and_play_house` — グーフィーのペイント＆プレイハウス: no usable samples in 閉園前
- `tdl_westernland_country_bear_theater` — カントリーベア・シアター: no usable samples in 閉園前
- `tdl_westernland_mark_twain_riverboat` — 蒸気船マークトウェイン号: no usable samples in 夕食前, 閉園前
- `tdl_westernland_tom_sawyer_island_rafts` — トムソーヤ島いかだ: no usable samples in 開園直後, 昼過ぎ, ショー前後, 夕食前, 夕食後, 閉園前
- `tdl_world_bazaar_omnibus` — オムニバス: no usable samples in 夕食前, 夕食後, 閉園前

### 2b. Low-confidence time bands (<3 samples)

- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: 昼前 = 2 samples
- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: 昼過ぎ = 1 samples
- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: ショー前後 = 1 samples
- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: 夕食後 = 1 samples
- `tdl_adventureland_tiki_room` — 魅惑のチキルーム：スティッチ・プレゼンツ“アロハ・エ・コモ・マイ！”: 閉園前 = 1 samples
- `tdl_fantasyland_castle_carrousel` — キャッスルカルーセル: 閉園前 = 2 samples
- `tdl_tomorrowland_stitch_encounter` — スティッチ・エンカウンター: 昼過ぎ = 2 samples
- `tdl_toontown_chip_and_dales_treehouse` — チップとデールのツリーハウス: 夕食後 = 1 samples
- `tdl_toontown_donalds_boat` — ドナルドのボート: 夕食後 = 1 samples
- `tdl_toontown_minnies_house` — ミニーの家: 昼前 = 2 samples
- `tdl_toontown_minnies_house` — ミニーの家: 夕食前 = 1 samples
- `tdl_toontown_minnies_house` — ミニーの家: 閉園前 = 1 samples
- `tdl_westernland_country_bear_theater` — カントリーベア・シアター: ショー前後 = 1 samples
- `tdl_westernland_country_bear_theater` — カントリーベア・シアター: 夕食前 = 2 samples
- `tdl_westernland_mark_twain_riverboat` — 蒸気船マークトウェイン号: ショー前後 = 1 samples
- `tdl_westernland_shooting_gallery` — ウエスタンランド・シューティングギャラリー: 閉園前 = 2 samples

### 3. Facility-ID mapping audit

- All mapping targets exist in master facility data.
- No currently actionable unmatched entries in the available unmatched file.

## tokyo_disneysea

- Active master attractions/greetings: 35
- Mapped active attractions: 33
- Generated profiles: 26
- Profile source observations: 18528

### 1. Profile missing facilities

- `tds_aw_g_001` — ヴィレッジ・グリーティングプレイス; raw observations=0
- `tds_lrd_g_001` — ミッキー＆フレンズ・グリーティングトレイル（ミッキー）; raw observations=0
- `tds_lrd_g_002` — ミッキー＆フレンズ・グリーティングトレイル（ミニー）; raw observations=0
- `tds_lrd_g_003` — ミッキー＆フレンズ・グリーティングトレイル（ドナルド）; raw observations=0
- `tds_lrd_g_004` — “サルードス・アミーゴス！”グリーティングドック; raw observations=0
- `tds_mh_a_002` — フォートレス・エクスプロレーション; raw observations=0
- `tds_ml_a_001` — アリエルのプレイグラウンド; raw observations=0
- `tds_pe_g_001` — ディズニーシー・プラザ（キャラクターグリーティング）; raw observations=0

### 2. Time-band coverage

- `tds_ac_a_004` — マジックランプシアター: no usable samples in 閉園前
- `tds_aw_a_005` — ビッグシティ・ヴィークル: no usable samples in 開園直後, 昼前, 昼過ぎ
- `tds_mh_a_001` — ヴェネツィアン・ゴンドラ: no usable samples in 開園直後, 昼前, 昼過ぎ

### 2b. Low-confidence time bands (<3 samples)

- `tds_ac_a_004` — マジックランプシアター: 夕食前 = 2 samples
- `tds_mh_a_001` — ヴェネツィアン・ゴンドラ: 閉園前 = 2 samples
- `tds_pd_a_002` — ニモ＆フレンズ・シーライダー: 閉園前 = 1 samples

### 3. Facility-ID mapping audit

- All mapping targets exist in master facility data.
- Active master attractions/greetings without a ThemeParks.wiki mapping (may be intentional if the source has no standby wait):
  - `tds_aw_a_006` — ディズニーシー・トランジットスチーマーライン（アメリカンウォーターフロント）
  - `tds_lrd_a_003` — ディズニーシー・トランジットスチーマーライン（ロストリバーデルタ）
- No currently actionable unmatched entries in the available unmatched file.

## Interpretation

- A 0/0/0 range is treated as unavailable by the scheduling engine and is therefore reported as missing coverage.
- v7.4.8 stores sampleCount per time band; nearest-band fallback requires at least 3 samples. Direct-band observations remain usable even when thin, but the source text exposes the exact band sample count.
- ThemeParks.wiki timestamps are UTC; time-band coverage must be classified after conversion to JST.
- An active master attraction without mapping is not automatically an error; some source entities do not expose a standby wait queue.

