# Changelog

## v2.6 — 行動履歴・AI学習データ基盤

- 共通行動履歴モデルを追加
- HistoryRepositoryとLocalHistoryRepositoryを追加
- 待ち時間の手動保存時に学習履歴を自動記録
- データ取得元と品質を保存
- AI予測値を学習対象から除外可能にした
- LearningEngineと学習データ要約を追加
- SharedPreferencesへ最大5000件保存
- バージョンを2.6.0+26へ更新

## v2.5 - 開発中

- プロダクトを「公式アプリと一緒に使うAIディズニープランナー」として再定義
- 移動時間エンジン基盤を追加
- FacilityLocation、AreaConnection、MovementEstimateを追加
- MovementRepositoryを追加
- LocalMovementRepositoryを追加
- ApiMovementRepositoryの雛形を追加
- MovementTimeEngineによる最短移動時間と到着予測を追加
- 公式マップ画像を使用しない方針を明文化
- ROADMAPをAI待ち時間予測・AI最適化中心へ再編
- README、ARCHITECTURE、PROJECT_STATUSを更新

## v2.4 - 開発中

- flutter analyze指摘17件を修正（構文、lint、初期化形式）

- 当日の残り予定再計算を追加
- 完了済み・進行中・確定固定予定の維持に対応
- 待ち時間と営業状態を再計算条件へ反映
- Before / After比較と承認後反映に対応
- 直前の再計算を1世代だけ元に戻す機能を追加

## v2.4（開発中）

- スケジュール再計算エンジンの設計を凍結
- 完了済み・進行中・確定固定予定を維持する再計算を実装予定
- 変更前後比較、承認後反映、Undoを実装予定

## v2.3（実装完了・動作確認待ち）

### リアルタイムデータ基盤

- `LiveDataRepository`を追加
- `LocalLiveDataRepository`を追加
- `ApiLiveDataRepository`の差し替え用雛形を追加
- `LiveOperatingStatus`と`LivePassStatus`を追加
- ローカルJSONから待ち時間・営業状態・パス状況を読み込む処理を追加
- 手動待ち時間をローカルJSONより優先するフォールバックを追加
- `LiveDataController`を追加
- `LiveController`をリアルタイムデータRepositoryへ接続
- データ取得時刻・読み込み状態・エラー状態を管理
- 未確認の運営情報を生成しない空マスターを追加
- エリアフィルターの「すべてのエリア」を「すべて」へ変更

### 確認待ち

- `dart format lib`
- `flutter analyze`で`No issues found!`確認
- Windows起動確認
- Today画面の手動待ち時間入力・再読み込み確認
- 空の営業状態・パス状況マスターで正常起動することを確認

------------------------------------------------------------------------

## v2.2（完了）

### 固定予定Domain・Repository

- `FixedTimeStatus { none, planned, confirmed }`を追加
- `PerformanceTimeOption`を追加
- `PerformanceScheduleRepository`を追加
- `LocalPerformanceScheduleRepository`を追加
- `assets/master/performance_schedules.json`を追加
- 公演時刻を`parkId`・`facilityId`・`date`で検索
- 未登録の公演時刻を自動生成しない処理を追加
- 旧保存データの固定時刻を`confirmed`として移行

### 固定予定編集UI

- 選択施設編集画面へ固定予定編集シートを追加
- DPA / PP / SPの取得なし・取得予定・取得済みに対応
- Entry Requestの抽選予定・当選・外れに対応
- Priority Seatingの予約なし・予約予定・事前予約済みに対応
- モバイルオーダーの受取時刻に対応
- 時刻選択を10分刻みに統一
- ショー・パレードの自由時刻入力を廃止
- ローカル公演マスターからの公演回選択に対応

### Schedule Engine

- 事前予約済みレストランを最優先で固定配置
- 確定済みショー・パレードを固定配置
- 確定済みDPA / PP / SP / Entryを固定配置
- `planned`状態は時刻未確定の通常候補として保持
- 同一開始時刻の固定予定競合を検出
- 競合時は自動移動せず警告を表示

### Plan Review / Today

- Plan Reviewから固定予定を編集して再生成可能
- Todayから固定予定を編集可能
- Todayで完了済み・進行中の予定を維持
- 変更後は未実施の残り予定を再計算
- おすすめ施設と残りスケジュールの再評価に対応

### 品質確認

- `flutter analyze`: `No issues found!`
- エリアフィルター文言を「すべて」へ調整

------------------------------------------------------------------------

## v2.1

-   Today画面を強化
-   ライブ待ち時間（ローカル）対応
-   DPA / Priority Pass / Standby Pass対応
-   Entry Request対応
-   Priority Seating対応
-   モバイルオーダー対応
-   ショー設定追加
-   SharedPreferences保存対応
-   GitHubへPush
-   flutter analyze: No issues found!

------------------------------------------------------------------------

## v2.0

-   おすすめ施設表示
-   待ち時間入力
-   色付きタグ
-   スクロールバー
-   折りたたみUI改善

------------------------------------------------------------------------

## v1.3

-   SharedPreferences永続化改善
-   AppState連携改善
-   flutter analyze対応
-   Design Freeze運用開始

------------------------------------------------------------------------

## v1.2

-   Global AppState導入
-   画面間データ共有
-   Schedule Engine改善

------------------------------------------------------------------------

## v1.1

-   Planner Data Model整備
-   Schedule Engine拡張

------------------------------------------------------------------------

## v1.0

-   Schedule Engine実装
-   基本スケジュール生成

------------------------------------------------------------------------

## v0.9

-   Planner Data Model追加

------------------------------------------------------------------------

## v0.8

-   Planner Settings追加

------------------------------------------------------------------------

## v0.7

-   Plan Builder追加

------------------------------------------------------------------------

## v0.6

-   Facility Browser追加
-   Facility Search追加
-   あいまい検索
-   カテゴリ検索
-   エリア検索
-   営業状態検索

------------------------------------------------------------------------

## v0.5

-   HomeControllerを追加
-   HomeScreenからRepositoryを呼び出す構成を追加
-   MockDataSourceとRepositoryImplをUIへ接続
-   ホーム画面にリゾート数、パーク数、施設数を表示
-   ホーム画面にパーク一覧を表示
-   ホーム画面に代表施設一覧を表示

## v0.4

-   Data Layerを追加
-   MockParkDataSourceを追加
-   MockFacilityDataSourceを追加
-   ParkRepositoryImplを追加
-   FacilityRepositoryImplを追加

## v0.3

-   Domain層を追加
-   Entityを追加
-   Value Objectを追加
-   Enumを追加
-   Repository Interfaceを追加
-   Domain Serviceを追加

## v0.2

-   Design Systemを追加
-   Material3デザイン基盤
-   共通Widget整備

## v0.1

-   Flutterアプリの基本構成
-   MainShell
-   Home
-   Plan Editor
-   Plan Review
-   Today
-   Settings