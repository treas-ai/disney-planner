# AI Planner Phase 1 実装メモ

## 2026-08-18

実地検証 8/12・8/13 を基準に、既存データ互換を維持したまま Phase 1 の基礎を追加。

- `PlanPreference.isExcluded`
  - 「今回は行かない」を明示可能。
  - 旧JSONでは `false`。
  - 通常候補生成時に除外する。
- `WishItemState`
  - `targetCount` / `completedCount` / `visitCount` / `repeatAllowed` を追加。
  - 同一店舗に複数の希望商品がある場合、1回の訪問で全達成扱いにしない基礎。
  - 旧JSONの `completed=true` は達成済みとして復元。
- 固定予定前15分の安全バッファ
  - `fixed_` 予定の直前を通常候補で埋めない。
- 閉店 urgency
  - 18時以前に終了する施設を、同じ希望時間帯の中で後回しにしすぎない。
  - 営業終了まで120分以内なら「後回しで利用機会を失う可能性」をAI理由へ追加。
- 回帰テスト
  - skipのJSON互換
  - 商品単位Wishの複数回収
  - 旧Wish JSON互換

次段階では UI から `isExcluded` を設定可能にし、商品Wishと施設候補の対応、closing urgency を候補スコア自体へ反映する。
