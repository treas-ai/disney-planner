# Disney Planner 標準開発ワークフロー

## 1. 普段の開発・起動

```powershell
.\dev.ps1
```

実行内容:

- 依存関係の変更を自動判定
- 必要な場合のみ `flutter pub get`
- Windows版を起動

`flutter analyze`と`flutter test`は実行しません。

## 2. 機能完成時の品質確認

```powershell
.\verify.ps1
```

実行内容:

- 必要な場合のみ `flutter pub get`
- `flutter analyze`
- `flutter test`

テストを一時的に省略する場合:

```powershell
.\verify.ps1 -SkipTests
```

## 3. リリース前の総合確認

```powershell
.\release_check.ps1
```

実行内容:

- 必要な場合のみ `flutter pub get`
- `flutter analyze`
- `flutter test`
- Windows版を起動

## pub getを強制する場合

```powershell
.\dev.ps1 -ForcePub
.\verify.ps1 -ForcePub
.\release_check.ps1 -ForcePub
```

## PowerShellで実行制限が出た場合

そのPowerShellウィンドウだけ許可します。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

## 標準運用

普段:

```powershell
.\dev.ps1
```

機能完成時:

```powershell
.\verify.ps1
```

Git保存前:

```powershell
.\release_check.ps1
```

リリース:

```powershell
git add .
git commit -m "Release vX.X"
git push
git tag vX.X
git push origin vX.X
```
