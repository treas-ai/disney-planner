# Disney Planner Stage 2 調査結果

アップロードされた軽量ソースは約3.43 MB / 588ファイルでした。
第1段階後はすでに十分軽量です。

今回の安全削除対象:
- assets/master.zip
  - pubspec.yaml から参照されていません。
  - 実行時は展開済み assets/master/ を使用しています。
- tool/master_data/output/migration_report.json
- tool/master_data/output/migration_report.txt
- tool/master_data/output/backups/
  - master data migration tool の生成物です。

今回は触らない:
- lib/
- assets/master/ 以下の実データ
- test/
- DB migrations
- docs/DESIGN_FREEZE_*
- PROJECT_STATUS.md
- DESIGN_V5_1_1.md
- tool/master_data/ のツール本体
- Android/iOS/Windows/macOS/Linux/Web のソース

理由:
古い設計書は容量が非常に小さく、削除による軽量化効果より履歴を失うリスクの方が大きいためです。
Dartファイル統合も現段階では行いません。
