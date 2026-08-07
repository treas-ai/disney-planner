# Disney Planner 最適化調査

対象: 2026-08-07 アップロード版

## 結論

現在の容量増加の大部分はソースコードではなく、Flutter/Windows の再生成可能ファイルです。
`lib` は約 2.3 MB ですが、`build` 約 431 MB、`.dart_tool` 約 220 MB、
`windows` 約 336 MB の大半が `windows/flutter/ephemeral` です。

安全な第1段階では、アプリコードやマスターデータを統合・削除せず、
再生成可能なビルド成果物だけを削除します。

## 安全に削除する対象

- build/
- .dart_tool/
- .flutter-plugins
- .flutter-plugins-dependencies
- windows/flutter/ephemeral/
- linux/flutter/ephemeral/
- macos/Flutter/ephemeral/
- ios/Flutter/ephemeral/
- android/.gradle/
- *.iml

これらは Git 管理対象にする必要がなく、必要になれば Flutter/IDE が再生成します。

## 今回は削除しないもの

- lib/
- assets/
- test/
- tool/
- android/, ios/, windows/, linux/, macos/ のソース側ファイル
- docs/
- .git/
- pubspec.yaml / pubspec.lock
- CHANGELOG.md

## 次の段階で精査できるもの

- `assets/master.zip` は pubspec およびコードから参照されていないため、削除候補。
- `tool/master_data/output/` の migration report / backup はランタイム不要。
- ルートの v5.1.1 系設計書と `PROJECT_STATUS.md` は現行 v7.3.x より古いため、
  docs/archive へ移動する候補。
- docs/ の DESIGN_FREEZE 群は容量自体は小さいため、削除よりアーカイブ整理を推奨。

第2段階は `verify.ps1` 成功後に、参照検索を行ってから実施してください。
