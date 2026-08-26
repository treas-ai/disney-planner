# ROADMAP

## Current milestone — Data-driven Schedule Optimization

### Phase 1: Movement foundation
- 施設・エリアの位置/所属情報を整理
- 移動時間データモデルを追加
- 移動時間 Repository を追加
- データ不足時のフォールバック規則を定義
- テスト追加

### Phase 2: Continuous value model
- 低・中・高の価値分類依存を除去
- 待ち時間を時間帯間で相対比較
- opportunity cost を計算
- データ信頼度を評価へ反映

### Phase 3: Total schedule cost
- 移動 + 待ち + 体験 + buffer を統合
- 前後予定を含む候補評価
- エリア往復ペナルティ
- 固定予定までの残り時間評価

### Phase 4: Service optimization
- DPA の実時間節約評価
- PP 等の時間指定サービスへの拡張
- ショーDPA/エントリー受付との整合

### Phase 5: Whole-day optimization
- 食事・休憩・公演を含む再最適化
- 希望退園時刻のソフト制約化（Step 1: 汎用Evaluator + 公式公演接続）
- AI評価用プランによる回帰評価

### Phase 6: Desired exit soft constraint
- [x] 汎用 `DesiredExitTimeEvaluator`
- [x] 公式公演候補への最小統合
- [x] 小幅超過を価値次第で許容するテスト
- [x] 超過コスト優勢時の拒否テスト
- [ ] AI評価用プラン検証
- [ ] downstream impact の実データ接続
- [ ] 公式公演以外への適用範囲を段階検討

## Design rule

凍結済み設計を実装途中で変更しない。
変更候補はバックログへ記録する。
