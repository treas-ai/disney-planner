# Project Status

更新日: 2026-08-20

## Current release

- Stable tag: **v7.4.6**
- `main` reflected: **v7.4.6 — Wait Profile Coverage Audit**
- Implementation candidate: **v7.4.7 — Nearest-band wait profile fallback**
- Application branch: `main`
- Raw live-data branch: `live-data`（v7.4.4で作成・実運用確認済み）
- Design policy: 既存のDesign Freezeを尊重し、ライブデータ基盤はUIを不用意に変更しない

## Verification

直近のWindows環境確認:

- `flutter analyze --no-pub`: No issues found!
- `flutter test --no-pub`: All tests passed!
- `verify.ps1`: Verification completed.

## Current focus

**TDR Live Data Quality Stabilization**

ThemeParks.wikiからTDL/TDSの待ち時間・DPA状態を自動収集する基盤が稼働しています。GitHub Actions標準scheduleは5分周期として安定しなかったため、外部スケジューラから `workflow_dispatch` を起動しています。

運用時間:

- 08:00〜21:55 JST: 5分間隔
- 22:00 JST: 最終1回

保存先:

- `tool/wait_data/github_history/`
- `tool/wait_data/dpa_history/`
- `tool/wait_data/unmatched/`
- `tool/wait_data/schedule_diagnostics.csv`

## v7.4.2 changes

- Frozen Journey alias typo fixed:
  - `annandelsasfrozenjourney`
  - → `annaandelsasfrozenjourney`
- DisneySea Electric Railway (Port Discovery) source UUID mapping corrected.

## Immediate acceptance check

次回作業では最初に以下を確認すること。

1. v7.4.2がGitHub `main` とタグへ反映済みであること
2. `Collect TDR live data` を1回実行すること
3. TDSの最新ログでunmatched件数を確認すること
4. Frozen Journeyが `tds_fs_a_001` として待ち時間CSVへ保存されること
5. 5分周期の自動起動が継続していること

## Git branch separation — v7.4.4

5分ごとの生観測データを `main` へ直接commitする方式は、通常開発のpushと継続的に競合することが確認されました。v7.4.4で次の構成へ変更しました。

- `main`: Flutterコード、マスター、Workflow、集約済み `wait_profiles` / `crowd_factors`
- `live-data`: `github_history`、`dpa_history`、`unmatched`、`schedule_diagnostics.csv` と月次archive
- 5分収集: `main` の最新collector/mappingを実行し、出力だけ `live-data` へcommit
- 月次圧縮: `live-data` 上で実施
- 日次profile再生成: `live-data` を読み、集約JSONだけ `main` へcommit

初回セットアップはv7.4.4をmainへpush後に `./setup_live_data_branch.ps1` を1回実行します。これにより5分Botによる `main` の `fetch first` 競合を解消します。

## v7.4.5 candidate — wait profile schedule integration

v7.4.4までの `ScheduleEngine` は、`Facility.waitTime` が無い通常待機アトラクションを優先度別20/30/45/60分で見積もっていた。`wait_profiles` は朝一候補スコアには使われていたが、スケジュールの `estimatedWaitMinutes` / 拘束時間 / `waitEstimateSource` には未接続だった。

v7.4.5候補では `ScheduleEngine.generate()` に `waitProfiles` を任意入力として追加し、Plan ReviewとAiDayPlannerから既存ロード済みprofilesを渡す。予定開始時刻をHistoricalWaitProfileGeneratorと同じ時間帯境界へ変換し、該当profileの `typicalMinutes` を通常待機の推定値へ使用する。0/0/0レンジは「サンプル無し」として安全側フォールバックへ戻す。DPA/PP/Standby Passの10分暫定バッファと `Facility.waitTime` の優先は維持する。

## v7.4.6 candidate — coverage audit and JST band fix

実プランでprofile接続自体は成功した一方、午後以降の多くが0/0/0となる原因を調査し、ThemeParks.wikiのUTC timestampをJSTへ変換せず時間帯分類していた問題を特定した。v7.4.6では `HistoricalWaitProfileGenerator` がUTC入力をJSTへ変換してから `afterOpening`〜`beforeClosing` の7帯へ分類する。既存履歴を再生成すれば過去の午後・夕方観測も正しい帯へ再配置される。

`tool/audit_wait_profile_coverage.py` は以下を監査する。

1. mapped + active attractionなのにprofileが無い施設
2. 7時間帯の生サンプル不足（raw historyがある場合は件数ベース）
3. masterに存在しないmapping target / profile ID
4. active master attractionでmappingが無い候補（自動修正はしない）
5. current unmatchedのうち現行alias/source alias/ignoreでも解決できない項目

collectorのunmatchedファイルはappend-onlyを廃止し「現在の未解決集合」に変更する。


## v7.4.7 candidate — nearest-band fallback

時間帯profileの対象帯が0/0/0の場合、同一施設内の最短距離にある有効帯を参照する。左右同距離なら代表待ち時間が大きい方を安全側として採用する。全帯に有効値が無い施設は補完対象外とし、従来の優先度別フォールバックへ戻す。リアルタイム/施設待ち時間とパス利用処理の優先順位は維持する。


## v7.4.8 Wait Profile Confidence（候補）
- `WaitTimeRange` に時間帯ごとの `sampleCount` を保存する。
- 直接該当する時間帯は実績値を使用し、根拠に「時間帯サンプルN件」を表示する。
- 欠損時間帯の近接参照は、参照元時間帯に3件以上の実績がある場合だけ使用する。
- 1〜2件しかない時間帯は近接外挿に使用せず、別の十分な近接帯が無ければ従来の安全側フォールバックへ戻す。
- 施設全体の `sampleCount` は互換性のため維持する。
