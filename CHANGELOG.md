# Changelog

## v3.3.1 - Area Label Fix

- エリアフィルターで内部IDが表示される問題を修正
- `tdl_resort_hotels` / `tds_resort_hotels` を「ディズニーホテル」と表示
- `tds_parkwide` を「パークワイド」と表示
- `tds_park_entrance` を「パークエントランス」と表示

## v3.3 - AI Intelligence

- AI判断結果を表す `AssistantInsight` を追加
- 判断の優先度・信頼度・スコアを追加
- 次予定までの残り時間を判断材料へ追加
- 施設優先度と営業状態をAI判断へ追加
- Event Impact Engineの影響をAI判断へ統合
- AIコンシェルジュ画面へ判断サマリーを追加
- AI判断エンジンの単体テストを追加
- バージョンを `3.3.0+330` へ更新

## v3.2.0 - Park Intelligence / Event Impact Engine

- EventImpactモデルを追加
- EventImpactRepositoryとLocalEventImpactRepositoryを追加
- EventImpactEngineを追加
- イベント開催中の移動ペナルティと経路制限判定を追加
- Schedule Engineへイベント影響を統合
- Movement Time Engineへイベント影響を統合
- AIコンシェルジュへ現在のイベント影響警告を統合
- TDL/TDSイベント影響マスターを追加
- 未確認の通行規制・停止情報を推測登録しない方針を明文化

## v3.1.2 - Entertainment Complete（TDSグリーティング）

- 東京ディズニーシー公式一覧に掲載されたグリーティング6施設を追加
- グリーティング専用カテゴリで検索・プラン選択・待ち時間入力に対応
- ミッキー、ミニー、ドナルド、ダッフィー、シェリーメイのキャラクターマスターを追加
- パークエントランスエリアを追加
- 公式施設URL・月間スケジュールURL・雨天情報・自動撮影情報を追加
- 終了済みまたは公式掲載を確認できない施設は追加しない

## v3.1.1

- 東京ディズニーシー公式「パレード／ショー一覧」を2026年8月3日時点で再確認
- 公式掲載の9プログラムをTDSマスターへ追加
- ビッグバンドビートは現行一覧に存在しないため追加対象外
- パークワイドエリアを追加
- 公演時刻は固定登録せず、公式月間スケジュールから選択する方針を維持

## v3.1

- TDS施設へ公式サイトリンクを追加
- TDSレストランへ公式メニューリンクと代表メニューを追加
- 2026-08-03時点の公式休止情報を反映
- ディズニーホテルレストランを朝食・昼食・夕食の候補として追加
- パーク退出、宿泊者条件、往復移動時間をデータ化
- ホテルレストラン予約時は往復移動を含めて固定予定へ配置


## v3.0（開発中）

- マスターデータを `assets/master/tokyo/{tdl,tds}` へ再編
- TDSの8エリア別施設マスターを追加
- TDSの主要アトラクション、計画上重要なレストラン・ショップを追加
- Master Data ManifestをschemaVersion 2へ更新
- 変動情報は公式アプリ確認を前提とする方針を明文化

## v2.9

- ローカルAIコンシェルジュを追加
- 現在のプランを参照する質問・回答機能を追加
- 次の予定、食事、公演、休憩、待ち時間に関する案内を追加
- 質問候補チップを追加
- 公式アプリとDisney Plannerの役割分担を回答画面に明記
- 将来のクラウドAIへ差し替え可能なAssistantEngineを追加

## v2.8 - AIプラン最適化

- AIプラン評価（100点満点）を追加
- 移動効率・待ち時間効率・優先度反映・固定予定保護を評価
- AI待ち時間予測を最適化判断へ接続
- エリア移動と優先度を考慮した改善案を生成
- Before / Afterのスコア比較を追加
- 利用者承認後のみ改善案を反映
- 確定固定予定を維持
- AI提案が参考情報であることを明示

## v2.7 — AI待ち時間予測

- WaitTimePredictionEngineを追加
- RuleBasedWaitTimePredictionEngineを追加
- 現在値と行動履歴を組み合わせる第1世代予測を追加
- 30分後・60分後・120分後の予測に対応
- 予測範囲・信頼度・予測根拠を追加
- データ不足時に架空の予測値を生成しない処理を追加
- Today画面へAI待ち時間予測パネルを追加
- 待ち時間更新後の予測再計算に対応
- バージョンを2.7.0+27へ更新

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