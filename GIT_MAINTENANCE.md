# v3.3.2 Git Maintenance

## 目的

Flutterの自動生成ファイルをGit管理対象から外し、今後は次のコマンドを安全に使える状態にします。

```powershell
git add .
```

## 対象外になるファイル

- `.dart_tool/`
- `.flutter-plugins`
- `.flutter-plugins-dependencies`
- `build/`
- 各プラットフォームの`ephemeral/`
- IDE・OSの一時ファイル

`lib/`、`assets/`、`test/`、各プラットフォームのソース、ドキュメントは引き続きGit管理します。

## 適用手順

ZIPをプロジェクト直下へ上書き後、PowerShellで実行します。

```powershell
cd C:\Development\disney_planner
Set-ExecutionPolicy -Scope Process Bypass
.\setup_git_maintenance.ps1
```

スクリプトは、すでにGit追跡されている生成ファイルだけをGitの管理対象から外します。PC上の実ファイルは削除しません。

## 確認

```powershell
git status
```

以下のような生成ファイルが、未追跡・変更一覧へ表示されなければ成功です。

```text
.dart_tool/
.flutter-plugins-dependencies
build/
```

## リリース

```powershell
git commit -m "Release v3.3.2 Git Maintenance"
git push

git tag v3.3.2
git push origin v3.3.2
```

## 今後の通常運用

```powershell
git add .
git commit -m "Release vX.X"
git push

git tag vX.X
git push origin vX.X
```
