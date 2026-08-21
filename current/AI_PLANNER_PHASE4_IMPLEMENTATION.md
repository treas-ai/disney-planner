# AI Planner Phase 4 実装メモ

2026-08-12 / 08-13 の実地ヒアリングを高度評価へ接続するため、以下の基盤を追加した。

- `DeferLossService`: 今行く場合と後回しした場合の待ち時間差を算出。
- `FatigueEstimationService`: 滞在時間・歩行・雨・荷物・休憩間隔から疲労度を推定。
- `SelloutRiskService`: 限定商品・must Wish・閉園までの残り時間から売切れリスクを評価。
- `PlannerBehaviorProfile`: Wish優先、ついで回収、期限、快適性などの重みを保持。
- `AdvancedCandidateScoringService`: 上記を統合し、次候補の高度評価値と説明理由を生成。

Phase 4では既存Schedule Engineを一気に置換しない。
まず評価基盤を独立追加し、既存61テストを維持しながら回帰テストで判断ルールを固定する。
次の実地再評価で重みを調整してから、Schedule Engineの候補選択へ段階接続する。
