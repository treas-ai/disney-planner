# Disney Planner v5.1.1 設計書（設計凍結）

## 目的
公開されている過去待ち時間を、出典と品質情報を失わずに取り込み、混雑係数・施設別7時間帯待ち時間・Wish候補評価・DPA自動割当へ接続する。

## 凍結方針
1. 特定Webサイトへ依存するスクレイピング処理はアプリ本体に持たない。
2. 取得済みCSV/JSONを共通形式へ正規化する。
3. 生データには出典、観測日時、祝日、イベント、除外状態と理由を保持する。
4. 係数は施設中央値を基準に、曜日・季節・祝日・イベントごとに生成する。
5. 信頼度はサンプル数30未満=low、30以上=medium、100以上=highとする。
6. 7時間帯は既存`WaitTimeBand`を変更しない。
7. 欠損時間帯は0/0/0を生成し、監査で未生成相当として検出可能にする。
8. Wish候補は優先度、予測待ち時間、体験時間、利用可能時間で評価する。
9. DPAは既存戦略と利用上限を守り、短縮効果の高い候補だけを選ぶ。
10. Schedule Engine本体の既存挙動は変更せず、選定済み施設・Preferenceを入力する境界で接続する。

## データフロー
公開履歴 → CSV/JSON → HistoricalWaitDataImporter → HistoricalWaitRecord → HistoricalWaitProfileGenerator → crowd_factors / wait_profiles → WishCandidateScoringEngine → DpaAutoAllocator → ScheduleEngine

## 監査
重複レコード、無効日時、負待ち時間、対象期間未設定、サンプル数0、信頼度未設定、7時間帯不足、期間外イベントをエラー対象とする。

## 非対象
利用規約に反する自動収集、認証回避、リアルタイム待ち時間の複製、外部データの無断再配布、UI全面改修。

設計凍結日: 2026-08-05
