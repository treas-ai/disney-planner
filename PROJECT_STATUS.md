# Disney Planner — PROJECT_STATUS

更新日: 2026-08-03
対象バージョン: v2.2 開発中
開発環境: Flutter / Windows / Git / GitHub / SharedPreferences
主プロジェクトパス: `C:\Development\disney_planner`

## 1. プロジェクト概要

Disney Planner は、ディズニーパークの事前計画と当日ナビを行う Flutter アプリです。
現在は東京ディズニーランド／東京ディズニーシーを中心に実装しています。

将来対象:
- 上海
- 香港
- アナハイム
- ウォルト・ディズニー・ワールド
- パリ
- ディズニー・クルーズライン

## 2. 開発方針

- 原則として省略なしの全文コードを提示する
- 差分よりコピー＆ペーストで動く形を優先する
- バージョン開始時に設計凍結する
- 変更後は `flutter analyze` で `No issues found!` を確認する
- 各バージョン完了時に commit / push / tag を行う
- 実際のパーク内で使えることを優先する
- 架空の公演時刻や未確認情報を自動生成しない
- UIの色・アイコン・ラベルは共通定義を使い、重複定義しない

## 3. 実装済み

### アプリ基盤
- Flutter基盤
- AppState / AppStateScope
- SharedPreferences永続化
- 選択施設・条件・生成済みプランの画面間共有
- モバイル／デスクトップ対応
- GitHub公開

### 主な画面
- Home
- Plan Editor
- Facility Browser
- Selected Facility Editor
- Plan Review
- Today
- Settings

### 施設検索
- 検索欄
- 部分一致検索
- ローマ字・ひらがな・カタカナ対応
- カテゴリ／エリア／営業状態フィルター
- アイコン＋名前＋件数
- 横スクロールバー
- フィルター折りたたみ
- 折りたたみ時の条件要約
- 選択項目への自動スクロール
- `FacilityVisualStyle`によるカテゴリ・エリア配色の共通化
- コンパクトなスマホUI

### 選択施設編集
- 施設追加／削除
- 並び替え
- 優先度
- 希望時間
- 待ち時間許容
- 食事利用
- DPA
- プライオリティパス
- スタンバイパス
- エントリー受付
- 自由鑑賞
- レストラン予約
- プライオリティ・シーティング
- モバイルオーダー
- メモ
- カプセルトイ優先
- 待ち時間手入力

### 固定時刻
現在の主なフィールド:

```dart
preferredPerformanceTime
reservationTime
scheduledAccessTime
```

意味:

```text
preferredPerformanceTime
→ ショー・パレード公演開始時刻

reservationTime
→ レストラン予約・PS・モバイルオーダー受取時刻

scheduledAccessTime
→ DPA・PP・SP・時間指定アトラクション利用時刻
```

### スケジュールエンジン
- 入園・退園
- 優先度
- 希望時間
- 待ち時間許容
- 営業時間
- 同一エリア優先
- 食事割り当て
- ショー固定時刻
- レストラン予約固定時刻
- DPA等の指定利用時刻
- 固定予定を通常予定より先に配置
- 重複する通常予定の回避
- 入り切らない予定を無理に追加しない

### Today画面
- 現在時刻
- 現在／次の予定
- 進行状況
- 当日予定一覧
- 待ち時間手入力・保存
- 30分経過時の要更新
- 待ち時間一覧
- 終了予想
- 次の固定予定に間に合うかの判定
- 今のおすすめ
- ショー・レストラン接近案内
- GlobalKeyによる正確な自動スクロール

接近案内の例:
- ビリーヴ！: 45分前
- ハーバーショー: 40分前
- ビッグバンドビート: 25分前
- ジャンボリミッキー: 20分前
- 予約レストラン: 30分前
- モバイルオーダー: 20分前

## 4. 現在の安定状態

直近で確認済み:

```text
flutter analyze
No issues found!
```

GitHub Push済み。

## 5. v2.2で進行中の設計

### プライオリティ・シーティング
- 事前予約できる固定予定として扱う
- 予約なし／予約予定／事前予約済みを区別する
- 予約済みは10分刻みで時刻選択
- スケジュール生成時に最優先で固定する

### DPA / PP / SP / Entry
- 取得予定／取得済みを区別する
- 取得予定は時刻未設定で保存可能
- 取得済みは10分刻みで選択
- 当日取得後にPlan ReviewまたはTodayから編集可能にする

### ショー・パレード
- 自由入力を廃止する
- 「1回目 10:50」のような公演回選択式にする
- ローカル公演マスターを参照する
- 公演時刻未登録時は架空時刻を作らない

### ローカル公演マスター
予定パス:

```text
assets/master/performance_schedules.json
```

Phase A:
- ローカルJSON

Phase B:
- Repository実装をAPIへ差し替え

## 6. 未実装・次の課題

- FixedTimeStatus
- 公演回選択用モデル
- PerformanceScheduleRepository
- LocalPerformanceScheduleRepository
- Plan Reviewから固定時刻編集
- Todayから固定時刻編集
- 固定予定競合警告
- 通常予定のみ再生成
- ショータグのモバイル横オーバーフロー完全解消
- 公式／許可済みAPIからのリアルタイム待ち時間取得
- GPS／マップ
- 通知

## 7. 重要な関連ファイル

```text
lib/domain/entities/plan_preference.dart
lib/domain/services/schedule_engine.dart
lib/app/state/app_state.dart
lib/features/facility/plan_preference_controller.dart
lib/features/facility/widgets/plan_preference_editor.dart
lib/features/facility/widgets/selected_facility_editor_sheet.dart
lib/features/facility/widgets/facility_visual_style.dart
lib/features/facility/widgets/unified_facility_filter_panel.dart
lib/features/plan_review/plan_review_screen.dart
lib/features/today/today_plan_screen.dart
```

## 8. 新チャット開始時の確認

1. 現在のブランチ
2. 最新commit
3. `flutter analyze`結果
4. v2.2ローカル公演マスターの実装状況
5. 変更対象ファイルの最新版
6. コンストラクタ・Controller・AppState APIの整合性

## 9. 完了判定

```text
dart format 対象ファイル
flutter analyze
No issues found!
実機／エミュレータ確認
git commit
git push
必要に応じてgit tag
```
