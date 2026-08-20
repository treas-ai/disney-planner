# Project Status

更新日: 2026-08-20

## Current release

- Stable tag: **v7.4.2**
- Implementation candidate: **v7.4.4 — Live data branch separation**
- Application branch: `main`
- Raw live-data branch: `live-data`（v7.4.4適用後に作成）
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

## Git branch separation — v7.4.4 candidate

5分ごとの生観測データを `main` へ直接commitする方式は、通常開発のpushと継続的に競合することが確認されました。v7.4.4候補では次の構成へ変更します。

- `main`: Flutterコード、マスター、Workflow、集約済み `wait_profiles` / `crowd_factors`
- `live-data`: `github_history`、`dpa_history`、`unmatched`、`schedule_diagnostics.csv` と月次archive
- 5分収集: `main` の最新collector/mappingを実行し、出力だけ `live-data` へcommit
- 月次圧縮: `live-data` 上で実施
- 日次profile再生成: `live-data` を読み、集約JSONだけ `main` へcommit

初回セットアップはv7.4.4をmainへpush後に `./setup_live_data_branch.ps1` を1回実行します。これにより5分Botによる `main` の `fetch first` 競合を解消します。
