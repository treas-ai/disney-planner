# Disney Planner 開発基盤 完成版 v2

## 改善点

- `flutter pub get`は必要な場合だけ1回実行
- その後の`analyze`・`test`・`run`は常に`--no-pub`
- 依存関係の確認が3回繰り返されない
- 改行コード差だけでは`pubspec.yaml`変更と判定しにくいよう調整

## 普段の起動

```powershell
.\dev.ps1
```

## 品質確認

```powershell
.\verify.ps1
```

## リリース前総合確認

```powershell
.\release_check.ps1
```

## pub getを強制

```powershell
.\verify.ps1 -ForcePub
```
