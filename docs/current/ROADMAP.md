# Disney Planner Roadmap

更新日: 2026-08-20  
現在の安定タグ: **v7.4.2**

## 完了済みの主要基盤

これまでのv3〜v7系で、以下の主要基盤を段階的に実装済みです。

- TDL/TDSマスターデータ分離・監査
- Live Operation Foundation / Official Data Service Foundation
- Wish List、候補確認、プラン生成、Today再計算
- AI Planner Phase 1〜4
- 運営状況・来園日ベースの休止判定
- 動的待ち時間スコアリング
- 移動時間・イベント影響・AI判断基盤
- 履歴・Undo/Redo・共有基盤
- ThemeParks.wiki待ち時間／DPA収集基盤

## v7.4.x — TDR Live Data Collection（現在）

### v7.4.1まで

- GitHub Actions用の軽量Pythonコレクタを導入
- TDL/TDS待ち時間を日別CSVへ保存
- DPA状態を別履歴へ保存
- unmatched施設を記録
- schedule diagnosticsを追加
- GitHub Actions標準scheduleの実行遅延を診断
- 外部スケジューラから `workflow_dispatch` を起動する方式へ移行
- JST 08:00〜21:55を5分間隔、22:00を最終収集として運用開始

### v7.4.2（完了）

- `Anna and Elsa's Frozen Journey` の正規化aliasを修正
- DisneySea Electric Railway (Port Discovery) のThemeParks.wiki UUIDマッピングを修正
- TDSライブデータの施設対応精度を改善

## 次の作業 — Live Data Quality Stabilization

優先順位順に進めます。

1. **v7.4.2反映後のmapping確認（確認済み）**
   - Frozen Journeyが `tds_fs_a_001` としてCSVへ保存されることを確認
   - 過去unmatched 5件が現在のmapping / ignore設定で処理済みであることを確認

2. **5分周期の実運用安定化（進行中）**
   - 外部 `workflow_dispatch` が5分刻みで継続していることを確認
   - GitHub標準scheduleの遅延・重複起動を確認
   - 標準scheduleを無効化し、外部スケジューラへ一本化
   - 08:00〜22:00の1日分について欠測・重複を最終監査

3. **履歴データ品質監査**
   - `observedAt`、施設ID、待ち時間、status、sourceEntityIdを検証
   - DPA履歴のstate / returnStart / returnEndを検証
   - 同一観測の重複排除が期待どおりか確認

4. **履歴集約の安定化**
   - `assets/master/wait_profiles/` と `crowd_factors/` の再生成経路を確認
   - GitHub収集履歴を既存のHistoricalWaitProfileGeneratorへ確実に接続

5. **予測ロジックへの接続**
   - 曜日・時間帯・混雑傾向を履歴から算出
   - 朝一候補評価と将来待ち時間予測へ利用
   - データ不足時は固定人気値を捏造せず、信頼度を下げる

## 次の改善 — Git運用

現在、自動収集Botが `main` に直接観測データをコミットするため、開発者のpushと競合し `fetch first` が発生することがあります。

候補:

- 収集データ専用ブランチへ分離
- Artifact / 外部ストレージ等への保存方式を検討
- mainへ反映する集約結果だけを限定的にコミット

**強制pushで解決しないこと。** 現状は `git pull --rebase origin main` を基本とします。

## その後の開発候補

- 待ち時間予測の精度評価UI
- DPA / PP / 運営状態を含むリアルタイム再計画強化
- ホテル・レストラン予約連携強化
- 実地テストでの入力負担・候補選択・AI配置評価
- PC・スマホ・同行者間共有の改善
- 公開版に向けたUI/UX最終調整

## リリース判定

各実装単位で以下を満たすことを基本とします。

```powershell
.\verify.ps1
```

期待結果:

- `flutter analyze --no-pub` → No issues found!
- `flutter test --no-pub` → All tests passed!
- Verification completed.

ライブデータ関連では加えて、GitHub Actionsログと保存CSVの実データを確認します。
