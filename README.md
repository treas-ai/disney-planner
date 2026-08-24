# Disney Planner

**公式アプリと一緒に使うAIディズニープランナー**

Disney Plannerはディズニー公式アプリの代替ではありません。チケット、予約、公式待ち時間、公式マップなどは公式アプリで確認し、本アプリは事前計画、当日のスケジュール管理、再計算、待ち時間履歴の活用、AIによる候補評価を補助します。

## 現在の開発状態

- 現在の安定タグ: **v7.4.6**
- `main` 反映済み: **v7.4.6 — Wait Profile Coverage Audit**
- 次期候補: **v7.4.7 — Nearest-band wait profile fallback**
- `flutter analyze --no-pub`: **No issues found!**（直近確認）
- `flutter test --no-pub`: **All tests passed!**（直近確認）
- TDL/TDS待ち時間・DPA状態の自動収集基盤: **稼働開始**
- ThemeParks.wiki施設マッピング: v7.4.2でTDSの追加修正

詳細は `docs/current/PROJECT_STATUS.md` と `docs/current/ROADMAP.md` を参照してください。

## 現在の主な機能

- 旅行設定 → Wish List → 候補確認 → プラン生成の計画フロー
- TDL/TDS施設検索・絞り込み
- 固定予定、予約、DPA/PP等を考慮したスケジュール生成
- Today画面と残り予定の再計算・比較・承認・Undo
- 運営状況・来園日ベースの休止判定
- 移動時間エンジン
- 待ち時間履歴・AI学習データ基盤
- 待ち時間予測と動的スコアリング基盤
- AIプラン最適化・リアルタイム再計画基盤
- ローカル共有・履歴基盤

## TDRライブデータ収集

ThemeParks.wiki の公開live APIから、東京ディズニーランド／東京ディズニーシーの待ち時間とDPA状態を収集します。

現在は GitHub Actions の `workflow_dispatch` を外部スケジューラから起動し、**JST 08:00〜21:55を5分間隔、22:00に最終1回**の収集を行う構成です。GitHub Actions標準のscheduled実行は遅延が大きかったため、5分周期の主トリガーには使用しません。

保存ブランチ: **`live-data`**（v7.4.4で正式導入。アプリ開発の `main` と分離）

保存先:

- 待ち時間: `tool/wait_data/github_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- DPA状態: `tool/wait_data/dpa_history/YYYY/MM/YYYY-MM-DD_<parkId>.csv`
- 未マッピング: `tool/wait_data/unmatched/<parkId>.txt`
- スケジュール診断: `tool/wait_data/schedule_diagnostics.csv`

施設対応表は `assets/master/live_mapping/themeparks_wiki_tokyo.json` です。v7.4.2では `Anna and Elsa's Frozen Journey` と DisneySea Electric Railway (Port Discovery) のマッピングを修正しました。

詳しくは `tool/wait_data/README.md` と `docs/current/THEMEPARKS_WIKI_UNMATCHED_FIX.md` を参照してください。

## 待ち時間データの利用方針

収集した履歴は、将来的な待ち時間予測・朝一候補評価・動的スケジュール最適化の入力に使用します。予測値は公式情報ではなく、公式アプリの確認を前提とした参考値として扱います。

次の重点は、**収集品質の監視 → unmatched解消確認 → 履歴集約 → 予測ロジックへの安定接続**です。

## 開発環境

通常確認:

```powershell
.\verify.ps1
```

個別確認:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter run --no-pub -d windows
```

依存関係を変更した場合のみ、必要に応じて `flutter pub get` を実行します。

## マスターデータ監査

```powershell
dart run tool/audit_master_data.dart
```

監査結果は `docs/audits/MASTER_DATA_AUDIT_REPORT.md` に出力します。

## Git運用

v7.4.4では、5分ごとの生観測データと月次圧縮結果を **`live-data`** ブランチへ分離しました。`main` はFlutterアプリ、設定、集約済み `wait_profiles` / `crowd_factors` を保持します。これにより5分ごとのBot commitが通常の開発pushと競合しません。

初回だけ、v7.4.4を `main` へpushした後に次を実行します。

```powershell
.\setup_live_data_branch.ps1
```

日次のwait profile再生成は23:35 JSTに `live-data` を読み、集約JSONだけを `main` へcommitします。この1日1回のcommitと手動pushが重なった場合だけ、強制pushせずrebaseします。

```powershell
git pull --rebase origin main
git push origin main
```

リリースタグ例:

```powershell
git tag -a vX.X.X -m "vX.X.X <summary>"
git push origin vX.X.X
```

今後は、開発用 `main` と自動収集データの競合を減らすため、収集データの保存ブランチ／保存方式の分離を検討します。

## 外部サービスと注意事項

- ThemeParks.wiki: ライブデータ取得元。アプリ表示時はクレジットを維持します。
- cron-job.org: 5分周期の外部トリガーとして利用中。
- GitHub PAT等の秘密情報はリポジトリ、README、スクリーンショット、チャットへ貼り付けません。
- 公式情報は必ずディズニー公式アプリ／公式サイトを優先します。

## v7.4.5候補 — wait_profiles のスケジュール接続

`wait_profiles` は朝一候補評価には既に使われていますが、v7.4.4までは `ScheduleEngine` の各施設の推定待ち時間・拘束時間には未接続でした。v7.4.5候補では、予定開始時刻を時間帯へ変換し、同一 `facilityId` / `parkId` の実績プロファイル中央値を通常待機の推定待ち時間へ使います。該当時間帯に有効な実績値が無い場合だけ従来の安全側フォールバックを維持します。

## v7.4.6候補 — Wait Profile Coverage Audit

実プランで実績profileの接続は確認できましたが、時間帯の多くが0/0/0になる原因を追跡した結果、ThemeParks.wikiの `observedAt` はUTC (`Z`) なのに、`HistoricalWaitProfileGenerator` がUTC時刻のままTDRの時間帯へ分類していたことを確認しました。v7.4.6候補ではUTCをJSTへ変換してから7時間帯へ分類します。

また `tool/audit_wait_profile_coverage.py` を追加し、profile未生成施設、時間帯別サンプル不足、マッピング対象不整合、現在のunmatchedを一覧化します。日次profile再生成Workflowでもこの監査を実行し、`docs/current/WAIT_PROFILE_COVERAGE_AUDIT.md` を更新します。施設IDは自動推測・捏造せず、疑わしい項目は監査結果として残します。

## v7.4.7候補 — 欠損時間帯の近接実績参照

対象時間帯の実績が0/0/0でも、同一施設の別時間帯に有効な実績があれば最も近い時間帯の `typicalMinutes` を利用します。同距離なら安全側として大きい代表値を採用します。施設全体に有効実績が無い場合は従来の優先度別フォールバックを維持し、架空の実績値は生成しません。


## v7.4.8 Wait Profile Confidence（候補）
- `WaitTimeRange` に時間帯ごとの `sampleCount` を保存する。
- 直接該当する時間帯は実績値を使用し、根拠に「時間帯サンプルN件」を表示する。
- 欠損時間帯の近接参照は、参照元時間帯に3件以上の実績がある場合だけ使用する。
- 1〜2件しかない時間帯は近接外挿に使用せず、別の十分な近接帯が無ければ従来の安全側フォールバックへ戻す。
- 施設全体の `sampleCount` は互換性のため維持する。

### v7.5.0 候補: Wait-aware Schedule Optimization

AIプラン生成は、配置後に待ち時間を表示するだけでなく、同一施設の時間帯別待ち時間変動を比較して次に行く施設を選択する。朝一だけ空きやすい施設が複数ある場合は、後回しした場合の待ち時間増加、優先度、移動時間を比較し、限られた朝枠を配分する。配置順を変える判断には時間帯サンプル3件以上の実績のみを使う。
### v7.5.0 candidate fix2
AIプラン生成は「朝一2件」を固定せず、各予定の配置後に残り全候補を再評価します。朝一しか空きにくい施設が複数ある場合は、後回ししたときの待ち時間増加、現在待ち時間、優先度、移動時間、希望時間を比較して朝枠を配分します。DPA利用設定が有効な場合は、十分な待ち時間削減が見込める対象を最大1件だけ保守的に自動割当します。未採用レストランは通常施設として追加しません。

## v7.5.2 candidate — Simple DPA / Entry Request Strategy
- 施設ごとのDPA指定を基本操作から外し、旅行設定で「アトラクションDPA 最大0〜3個」を指定する。
- AIの事前DPA自動配分はアトラクションだけを対象にし、設定上限以内で高効果候補へ配分する。
- ショー／パレードDPAはアトラクションDPA上限へ含めない。エントリー受付を先に行い、落選時のみ「DPAを検討」を既定フォールバックにする。
- 既存の施設別DPA・時刻指定は詳細設定／当日確定情報として互換維持する。
- 旧保存データの `canUseDpa=true` はアトラクションDPA最大1個として移行する。



## v7.5.2 candidate fix — whole-day DPA and evening reuse
- Attraction DPA allocation now evaluates the resulting whole-day schedule instead of ranking a facility in isolation.
- `maximum N` remains a ceiling: an extra DPA is used only when the simulated day plan improves.
- High-priority wish candidates remain available as reserve candidates so meal/show anchors do not create avoidable multi-hour gaps.
- Shows and parades without a resolved performance time are not inserted into arbitrary free slots; resolved/entry-request performance times remain fixed anchors.
- Evening free time can therefore be reused by remaining wanted attractions around fixed show/parade plans rather than being treated as automatically bad or automatically filled.

### Whole-day open-time handling (v7.5.2 candidate fix2)
AIプランは希望施設・食事・固定公演を配置した後、60分以上の長い空白を自由時間として明示します。17:00以降はショー・パレード鑑賞にも使える自由枠として表示しますが、実在する公演時刻は捏造しません。公式/選択済みの公演時刻が解決できた場合は固定公演を優先します。

## v7.5.2 candidate — Official performance opportunity awareness
- 長時間の自由枠を「ショー・パレード」と曖昧表示せず、来園日・対象パークに一致する `performance_schedules.json` の公式公演時刻を候補として表示する。
- 未選択のショーを自動予約・当選扱いにはしない。選択済みで公演時刻が解決されたショー／パレードは従来どおり固定予定を優先する。
- エントリー受付対象／DPA対象も候補表示に付記する。
