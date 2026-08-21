# AI Planner Phase 2 実装メモ

## 今回の実装

- 施設座標を使った近接性評価 `FacilityProximityService`
- directExit / veryNear / near / sameArea / far の近接レベル
- 座標ベースの徒歩時間概算
- 同一希望時間・同一エリア・同一優先度内での局所的な往復削減
- 目的地までの小さな寄り道でWishを回収する `RoutePickupService`
- 明示的に除外した施設はRoute Pickup対象外
- Phase 2回帰テスト追加

## 安全性

既存のRouteOptimizerの大分類（希望時間、閉店優先、エリア、優先度）は維持する。
座標による並べ替えは同一条件の局所グループ内だけに限定し、既存の優先順位を壊さない。

## 次段階

RoutePickupServiceは判断基盤として追加した。固定予定までの残り時間を含むScheduleEngineへの
自動挿入は、誤挿入を避けるため、実地回帰データと合わせて次の統合段階で行う。
出口専用座標が追加された場合はFacilityProximityServiceの内部実装を差し替える。
