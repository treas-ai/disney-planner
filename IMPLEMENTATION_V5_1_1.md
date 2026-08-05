# v5.1.1 実装フェーズ

## 追加コンポーネント
- `HistoricalWaitRecord`: 正規化済み履歴レコード
- `HistoricalWaitDataImporter`: CSV/JSON取込と行単位エラー
- `HistoricalWaitProfileGenerator`: 係数・7時間帯プロファイル生成
- `WishCandidateScoringEngine`: 混雑予測を使った候補採点と件数絞り込み
- `DpaAutoAllocator`: 既存DPA戦略を使った自動割当
- `generate_historical_wait_profiles.dart`: JSON成果物生成CLI

## 実行手順
```powershell
flutter pub get
flutter analyze
flutter test
.\verify.ps1
```

## データ生成
```powershell
dart run tool/generate_historical_wait_profiles.dart tokyo_disneyland <入力CSVまたはJSON> "出典・URL・取得日"
dart run tool/audit_v5_1_data.dart
```

## Git
```powershell
git add .
git commit -m "feat: implement v5.1.1 historical wait pipeline"
git tag v5.1.1
git push origin main
git push origin v5.1.1
```
