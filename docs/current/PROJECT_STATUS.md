# Project Status

更新日: 2026-08-20

## Current release

- Stable tag: **v7.4.2**
- Branch: `main`
- Design policy: 既存のDesign Freezeを尊重し、ライブデータ基盤はUIを不用意に変更しない

## Verification

直近のWindows環境確認:

- `flutter analyze --no-pub`: No issues found!
- `flutter test --no-pub`: All tests passed!
- `verify.ps1`: Verification completed.

## Current focus

**TDR Live Data Quality Stabilization**

ThemeParks.wikiからTDL/TDSの待ち時間・DPA状態を自動収集する基盤が稼働しています。GitHub Actions標準scheduleは5分周期として安定せず、外部スケジューラの `workflow_dispatch` と重複起動することも確認されたため、標準scheduleを無効化しました。現在は外部スケジューラからの `workflow_dispatch` のみを使用します。

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

## Acceptance check result

2026-08-20の確認結果:

1. Frozen Journeyは `tds_fs_a_001` / `9fb0c97c-ebf7-4c25-8ea7-a3f4fe2aa9ec` として待ち時間CSVへ保存済み。
2. 過去のunmatched 5件は、現在のmappingではalias / source UUID mapping / ignore設定のいずれかで処理済み。
3. 外部 `workflow_dispatch` は08:00以降5分刻みで継続しており、確認区間では欠測なし。
4. GitHub標準scheduleによる遅延した追加実行が混在していたため、重複トリガーを防ぐ目的で標準scheduleを無効化。

## Known operational issue

GitHub Actions Botが収集データを `main` へ直接commitするため、ローカル開発者のpushと競合することがあります。`fetch first` が出た場合は強制pushせず、原則として以下を使用します。

```powershell
git pull --rebase origin main
git push origin main
```

中期的には収集データを開発用mainから分離する方式を検討します。
