# 新チャット引き継ぎプロンプト

以下を新しいChatGPTチャットの最初のメッセージとして貼り付けてください。

---

Disney Planner（Flutter）の開発を前チャットから引き継いでください。私はFlutter/Git初心者なので、操作手順は具体的に説明してください。コード修正が必要な場合は差分だけではなく、可能ならそのまま上書きできる完成ファイルまたはZIPをください。設計済みUIは不用意に変更しないでください。

## 現在地点

- プロジェクト: Disney Planner
- ブランチ: `main`
- 現在の安定タグ: **v7.4.2**
- v7.4.2: `Fix TDS live data facility mappings`
- 直近の `verify.ps1` は `flutter analyze --no-pub: No issues found!` / `flutter test --no-pub: All tests passed!`
- README / Roadmap / Project Status / wait_data README は2026-08-20時点へ更新済み

## TDRライブデータ収集

ThemeParks.wikiの公開live APIからTDL/TDSの待ち時間とDPA状態を取得しています。

主なファイル:

- `.github/workflows/collect-tdr-live-data.yml`
- `tool/github_collect_themeparks_wiki.py`
- `tool/log_schedule_diagnostic.py`
- `assets/master/live_mapping/themeparks_wiki_tokyo.json`
- `tool/wait_data/github_history/`
- `tool/wait_data/dpa_history/`
- `tool/wait_data/unmatched/`
- `tool/wait_data/schedule_diagnostics.csv`

GitHub Actions標準scheduleが5分周期で安定せず、実際には約40〜60分間隔になることがあったため、無料のcron-job.orgからGitHub APIの `workflow_dispatch` を呼ぶ方式へ変更しました。

現在の外部スケジュール:

- 08:00〜21:55 JST: 5分ごと
- 22:00 JST: 最終1回

cron-job.org → GitHub API → GitHub Actions → ThemeParks.wiki取得 → CSV保存 → mainへbot commit、まで実動確認済みです。

## 直近で解決したunmatched

TDSで `1 unmatched` が発生し、原因を調査しました。

ThemeParks.wiki:

- `Anna and Elsa's Frozen Journey`
- UUID: `9fb0c97c-ebf7-4c25-8ea7-a3f4fe2aa9ec`

Disney Planner側:

- `tds_fs_a_001`

原因は `themeparks_wiki_tokyo.json` のalias typoでした。

誤:
`annandelsasfrozenjourney`

正:
`annaandelsasfrozenjourney`

また DisneySea Electric Railway (Port Discovery) のsource UUIDも修正しました。

正しいUUID:
`c8744918-42c0-427d-8947-c3dbd1abf8d5`

これらは **v7.4.2** に反映済みです。

## 次に最優先でやること

1. GitHub Actionsの `Collect TDR live data` をv7.4.2状態で実行／最新実行を確認する。
2. 最新ログで `tokyo_disneysea: ... 0 unmatched` になったか確認する。
3. Frozen Journeyが `tds_fs_a_001` として `github_history` CSVへ保存されたか確認する。
4. `tool/wait_data/unmatched/tokyo_disneysea.txt` は過去検出値が残る仕様なので、ファイルの存在だけで失敗判定しない。
5. 5分周期の実行履歴と `schedule_diagnostics.csv` を確認し、欠測・重複を評価する。
6. その後、GitHub収集履歴 → wait_profiles/crowd_factors → 待ち時間予測・動的スコアリングへの接続を確認する。

## Git運用上の注意

自動収集botが5分ごとに `main` へデータcommitするため、手動push時に次のエラーが起きやすいです。

`[rejected] main -> main (fetch first)`

強制pushは禁止。基本は:

```powershell
git pull --rebase origin main
git push origin main
```

ただしrebase中にもbotがpushして再競合する場合があります。中期的には、自動収集データを `main` とは別ブランチ／別保存方式へ分離する改善を検討してください。

## 進め方

まず私に大量の説明をするのではなく、現在のZIP／リポジトリ内容を確認して、上記の「次に最優先でやること」の1から再開してください。必要な確認画面やコマンドを初心者向けに案内してください。

---
