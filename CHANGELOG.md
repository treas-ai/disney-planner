# Changelog

## v2.2（開発中）

### 実装済み（v2.2-A）

-   `FixedTimeStatus { none, planned, confirmed }`を追加
-   `PerformanceTimeOption`を追加
-   `PerformanceScheduleRepository`を追加
-   `LocalPerformanceScheduleRepository`を追加
-   `assets/master/performance_schedules.json`を追加
-   公演時刻を`parkId`・`facilityId`・`date`で検索する構成を追加
-   公演時刻未登録時に仮時刻を生成しない方針を実装
-   旧保存データの固定時刻を`confirmed`相当として読み込む互換処理を追加

### 継続実装予定（v2.2-B以降）

-   ショー・パレードの公演回選択UI
-   DPA / PP / SPの取得予定・取得済みUI
-   Priority Seatingの予約状態UI
-   10分刻み時刻選択
-   Plan Review / Todayから固定予定編集
-   固定予定維持での再生成
-   固定予定競合警告

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
