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

## Known operational issue

GitHub Actions Botが収集データを `main` へ直接commitするため、ローカル開発者のpushと競合することがあります。`fetch first` が出た場合は強制pushせず、原則として以下を使用します。

```powershell
git pull --rebase origin main
git push origin main
```

中期的には収集データを開発用mainから分離する方式を検討します。
