# 2026年10月 運営・季節コンテンツ更新

更新日: 2026-09-09

## 実装方針

来園日を基準に、その日に運営していないアトラクション・ショー・パレードを
「やりたいこと」とスケジュール候補から除外する。

Facility に `availableStartDate` / `availableEndDate` を追加し、期間限定公演を
開催期間内だけ選択可能にした。公式休止は `closureStartDate` / `closureEndDate`
で来園日判定する。`isOperating` は現在時点の互換情報として扱い、将来の再開日が
公式に判明している場合は target date を優先する。

## Disney Halloween 2026

- 開催期間: 2026-09-16 ～ 2026-10-31
- Summer Wish Pack: 2026-09-14まで
- Halloween Wish Pack: 2026-09-16から自動表示
- Reach for the Stars: Everlasting Dreams: 2026-09-14まで
- Baymax Mission Cooldown: 2026-09-14まで
- TDL Villains Halloween / Night High Halloween を追加
- TDS Halloween Greeting / Night High Halloween を期間限定運営として有効化

## 10月アトラクション休止

TDL:
- 空飛ぶダンボ: ～10/22
- 魅惑のチキルーム: 9/24～10/23
- シンデレラのフェアリーテイル・ホール: 10/1～未定
- グーフィーのペイント＆プレイハウス: 10/26～10/30

TDS:
- タワー・オブ・テラー: 9/28～11/5
- インディ・ジョーンズ・アドベンチャー: ～11/29
- トランジットスチーマーライン（メディテレーニアンハーバー）: ～11/30
- マーメイドラグーンシアター: 長期休止継続

## 10月ショースケジュール

`assets/master/performance_schedules.json` に2026年10月の主要TDL/TDS公演時刻を追加。
10/2 TDL短縮営業日のエレクトリカルパレード／ナイトハイ休止も反映した。
