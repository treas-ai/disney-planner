# GitHub Pages 自動デプロイ

## 公開URL

https://treas-ai.github.io/disney-planner/

## 自動公開

`main`ブランチへPushすると、GitHub Actionsが次を実行します。

1. Flutter環境を準備
2. `flutter pub get`
3. `flutter analyze --no-pub`
4. `flutter test --no-pub`
5. `/disney-planner/`向けにFlutter Webをビルド
6. GitHub Pagesへ公開

## GitHub側の初回設定

リポジトリの次の画面を開きます。

```text
Settings
→ Pages
→ Build and deployment
→ Source
→ GitHub Actions
```

## 手動で再公開

```text
Actions
→ Deploy Flutter Web to GitHub Pages
→ Run workflow
→ Branch: main
→ Run workflow
```

## 更新確認

Actionsが緑色のチェックになった後、次を開きます。

https://treas-ai.github.io/disney-planner/

設定画面に`アプリバージョン v4.0.1`と表示されれば更新完了です。

古い画面が残る場合は、ブラウザで強制再読み込みします。

Windows:
```text
Ctrl + F5
```

スマートフォン:
- ブラウザのページを再読み込み
- 改善しない場合はサイトデータ／キャッシュを削除
