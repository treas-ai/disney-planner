# Disney Planner — ARCHITECTURE

更新日: 2026-08-03

## プロダクト境界

Disney Plannerは公式アプリを補助するAIプランナーです。公式アプリが担うチケット、購入、予約、公式地図などを再実装せず、計画・予測・最適化・判断支援へ集中します。

## レイヤー

```text
Presentation
  Screens / Widgets / Controllers

Application State
  AppState / AppStateScope

Domain
  Entities / Enums / Services / Repository Interfaces

Data
  Local Repository / API Repository / JSON / SharedPreferences
```

## AIへ向けたエンジン構成

```text
Planning Engine
Prediction Engine
Recommendation Engine
Learning Engine
Movement Time Engine
```

v2.5では`MovementTimeEngine`を実装します。Prediction、Recommendation、Learningは後続バージョンで段階的に実装します。

## 移動時間

```text
UI / Controller
  ↓
MovementRepository
  ↓
LocalMovementRepository または ApiMovementRepository
```

Domain:

- `FacilityLocation`
- `AreaConnection`
- `MovementEstimate`
- `MovementTimeEngine`

原則:

- 公式マップ画像を使用しない
- 位置は独自相対座標として保持する
- 確認していない移動時間を実データとして登録しない
- 未登録時はフォールバックであることを明示する
- 将来は到着予定時刻を待ち時間予測へ渡す

## Repository差し替え

Phase A:

```text
LocalMovementRepository
→ assets/movement/*.json
```

Phase B:

```text
ApiMovementRepository
→ 許可済みAPI
```

## 品質基準

```powershell
dart format lib
flutter analyze
```

期待結果:

```text
No issues found!
```


## 行動履歴・学習データ（v2.6）

```text
Today / LiveWaitTimeController
  → HistoryRepository
    → LocalHistoryRepository（SharedPreferences）
    → 将来 SQLite / Cloud

LearningEngine
  → 学習対象データの品質判定・要約
  → v2.7 Prediction Engineへ入力
```

AI予測値は履歴として識別可能にし、実測データと混同しない。低品質データと予測値は標準では学習対象外とする。

## Prediction Layer（v2.7）

```text
Today UI
  -> LivePredictionController
  -> WaitTimePredictionEngine
  -> RuleBasedWaitTimePredictionEngine
  -> HistoryRepository / 現在待ち時間
```

Prediction Engineは将来、統計・機械学習・クラウド実装へ差し替え可能とする。
## Plan Optimization
`PlanOptimizationEngine`はPlan Reviewから呼び出され、Prediction Engineの結果、施設エリア、優先度、固定予定を評価して改善案を返します。UIは承認前にスケジュールを変更しません。


## Assistant Layer
```text
AssistantScreen → AssistantController → AssistantEngine → RuleBasedAssistantEngine
```
将来はCloudAssistantEngineへ差し替え可能。


## v3.0 Master Data Layout

```text
assets/master/tokyo/tdl/*.json
assets/master/tokyo/tds/*.json
```

`master_manifest.json`だけが物理ファイルパスを知り、UIとDomainはパーク別ディレクトリを認識しません。
## Event Impact Layer

`EventImpactRepository → EventImpactEngine → MovementTimeEngine / ScheduleEngine / AssistantEngine` の依存方向で、イベント影響を共通利用する。
## AI Intelligence

`AssistantIntelligenceEngine` が予定時刻、施設優先度、営業状態、イベント影響を評価し、`AssistantInsight`を生成する。

## Master Data Quality Layer

```text
Master JSON
  -> MasterDataValidator (起動を止める構造検証)
  -> MasterDataAuditor (品質警告と網羅状況)
  -> Markdown Audit Report
```

Validatorは不正な構造を拒否し、Auditorは公式URL・メニュー・確認日の不足を可視化します。

## Live Operation Architecture (v3.5)

```text
Assistant / Schedule
        ↓
LiveOperationRepository
        ↓
MockLiveOperationRepository（v3.5）
        ↓ 将来差し替え
API / Approved Data Source
```

UIとAIは`LiveOperationSnapshot`だけを参照し、取得元を意識しません。Mock情報には`isMock`を付け、公式情報と誤認されない表示を必須とします。

