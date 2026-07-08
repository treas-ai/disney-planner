# Disney Planner - CONTRIBUTING

---

# 1. プロジェクト概要

Disney Planner は

「世界中のディズニーパーク・ディズニークルーズに対応するAIプランナー」

を目標とした長期開発プロジェクトです。

Flutter学習用ではなく、

実際にパークで使用できるレベルのアプリケーションを目指します。

---

# 2. 開発方針

本プロジェクトでは

「動くコード」

より

「保守できるコード」

を優先します。

設計を重視し、

長期間の運用を前提として開発します。

---

# 3. Version管理

Versionは以下の順で進めます。

v0.1 Foundation

v0.2 Design System

v0.3 Domain Model

v0.4 Data Layer

v0.5 Mock Data

v0.6 Facility

v0.7 Settings

v0.8 Planner

v0.9 Schedule Engine

v1.0 MVP Release

---

# 4. 設計凍結ルール

各Version開始前に

設計レビュー

↓

設計凍結

↓

実装

↓

レビュー

↓

Git保存

↓

次Version

を徹底します。

Version途中で仕様変更は行いません。

---

# 5. Backlog

新しいアイデアは

現在のVersionへ追加しません。

Backlogへ登録し、

次Version開始時に採用を検討します。

---

# 6. Git運用

Version完了時

git add .

git commit

git push

git tag

git push origin

までを1セットとします。

---

# 7. Commitルール

例

v0.3 Complete - Domain Model

v0.6 Add Facility Screen

Fix AppButton Padding

Refactor Repository

---

# 8. Git Tag

Version終了時

v0.1

v0.2

v0.3

...

タグを付与します。

---

# 9. ADR

Architecture Decision Record

設計変更を行う場合は

必ず理由を残します。

例

ADR-0001

AppScaffoldを導入

理由

画面共通化

---

# 10. コードレビュー

全Version終了時

レビューを行います。

確認項目

・保守性

・可読性

・命名

・責務

・再利用性

・拡張性

---

# 11. フォルダ構成

lib/

app/

core/

domain/

data/

features/

shared/

を基本構成とします。

---

# 12. Domain

Business Logic

を保持します。

Entity

ValueObject

Repository Interface

Domain Service

のみ配置します。

---

# 13. Data

Repository実装

SQLite

API

MockData

を配置します。

---

# 14. Features

画面

Widget

Controller

のみ配置します。

Business Logicは禁止です。

---

# 15. Shared

全体で共通利用する

Widget

Utility

Extension

を配置します。

---

# 16. 命名規則

クラス

UpperCamelCase

変数

lowerCamelCase

定数

lowerCamelCase

ファイル

snake_case.dart

を使用します。

---

# 17. Widget方針

直接Scaffoldは禁止

AppScaffoldを使用

直接Buttonは禁止

AppButtonを使用

直接Cardは禁止

AppCardを使用

---

# 18. Theme方針

色は

AppColors

余白は

AppSpacing

角丸は

AppRadius

文字は

AppTypography

を使用します。

---

# 19. Repository方針

Repository Interface

↓

Mock

↓

SQLite

↓

FastAPI

へ差し替え可能な構造とします。

---

# 20. AI方針

Flutterから

直接スクレイピングは行いません。

FastAPI経由で情報取得します。

AIは

Domain Service

を利用します。

---

# 21. 品質方針

コード重複禁止

Magic Number禁止

責務分離

SOLID原則を意識

リファクタリング歓迎

---

# 22. 実装手順

設計

↓

設計凍結

↓

実装

↓

動作確認

↓

レビュー

↓

Git保存

↓

Tag

↓

CHANGELOG更新

↓

次Version

---

# 23. Disney Plannerの最終目標

世界中のディズニーリゾートに対応し

AIが

移動時間

待ち時間

ショー

レストラン

DPA

Priority Pass

Single Rider

予約

天候

を考慮して

最適な一日のプランを生成できること。

---

このルールをDisney Plannerの標準開発ルールとします。