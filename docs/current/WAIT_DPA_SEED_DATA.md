# Wait / DPA Seed Data

初期検証用に実測・公開統計を投入する。

## 待ち時間
- TDSの主要DPAアトラクション7施設
- TDR Waits dashboard の2026-08-02公開観測系列から時間帯Profileを生成
- 各Profileには source / calculatedAt / sampleCount を保持
- TDLは十分な施設別時間帯系列を今回取得できなかったため、固定値を捏造せず空のまま

## DPA完売
- TDS: 2026-08-19取得時点の過去30日平均完売時刻
- TDL: TDR Waits 2026-03-15公開分析の過去30日平均
- 古い統計と新しい統計を同じ信頼度として扱わない前提
- 平均完売時刻は保証値ではなく、RecommendationのUrgency入力用

## 今後
ThemeParks.wiki等から継続観測してDisney Planner独自履歴へ置換する。
第三者サイトの大量スクレイピングを前提としない。
