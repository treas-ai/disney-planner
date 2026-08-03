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
