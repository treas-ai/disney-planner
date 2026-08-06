# Disney Planner v6.2.0 Home Refactor 設計凍結

## 目的

ホーム画面のUI改善を継続しやすくするため、1,300行を超えていた `home_screen.dart` を責務別の part ファイルへ分割する。

## 凍結事項

- 表示内容、画面遷移、状態判定ロジックは変更しない。
- `HomeScreen` と `_HomeScreenState` は `home_screen.dart` に残す。
- Hero、進捗、来園・施設、スケジュール、共通部品を分割する。
- privateクラスの可視性と既存APIを維持するため Dart の `part` を使用する。
- 次回以降のUI変更は、対象partファイルだけを修正する。

## ファイル構成

```text
lib/features/home/
├── home_screen.dart
└── widgets/
    ├── home_hero_card.part.dart
    ├── home_progress_card.part.dart
    ├── home_visit_summary_card.part.dart
    ├── home_schedule_card.part.dart
    └── home_shared_widgets.part.dart
```

## 品質確認

```powershell
.\verify.ps1
.\dev.ps1
```
