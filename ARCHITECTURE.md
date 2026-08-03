# Disney Planner — ARCHITECTURE

更新日: 2026-08-03

## 1. 設計原則

- UIはデータ取得元を知らない
- Controllerは画面状態と操作を担当する
- Domainは計画ルールを担当する
- Repositoryはデータ取得方法を隠蔽する
- Local / API / Firebase / Supabaseを差し替え可能にする
- 公演時刻・待ち時間をUIへ直書きしない
- 色・アイコン・ラベルを重複定義しない
- 固定予定と通常予定を分離する
- 架空の運営情報を生成しない
- 旧保存データとの互換性を維持する

## 2. レイヤー

```text
Presentation
  Screens
  Widgets
  Controllers

Application State
  AppState
  AppStateScope

Domain
  Entities
  Enums
  Services
  Repository Interfaces

Data
  Local Repositories
  API Repositories
  JSON / SharedPreferences
```

## 3. 推奨フォルダ構成

```text
lib/
├── app/
│   ├── main_shell.dart
│   └── state/
│       ├── app_state.dart
│       └── app_state_scope.dart
├── core/
│   ├── theme/
│   └── widgets/
├── domain/
│   ├── entities/
│   ├── enums/
│   ├── repositories/
│   └── services/
├── data/
│   ├── local/
│   ├── remote/
│   └── models/
└── features/
    ├── home/
    ├── facility/
    ├── plan_editor/
    ├── plan_review/
    ├── today/
    ├── live/
    └── settings/
```

## 4. 主なController

```text
FacilityController
→ 検索・絞り込み・営業状態

PlanBuilderController
→ 選択施設・並び順

PlanPreferenceController
→ 優先度・利用方法・固定時刻

ScheduleController
→ スケジュール生成・再生成

LiveController
→ Today・待ち時間・現在時刻

LiveWaitTimeController
→ 手動待ち時間保存
```

## 5. Repository構成

### 公演時刻

```dart
abstract interface class PerformanceScheduleRepository {
  Future<List<PerformanceTimeOption>> findOptions({
    required String parkId,
    required String facilityId,
    required DateTime date,
  });
}
```

Phase A:

```text
LocalPerformanceScheduleRepository
→ assets/master/performance_schedules.json
```

Phase B:

```text
ApiPerformanceScheduleRepository
→ 外部API
```

### 待ち時間

```dart
abstract interface class LiveDataRepository {
  Future<List<LiveWaitTime>> fetchWaitTimes({
    required String parkId,
  });
}
```

### 施設

```dart
abstract interface class FacilityRepository {
  Future<List<Facility>> loadFacilities({
    required String parkId,
  });
}
```

## 6. 固定時刻モデル

```dart
enum FixedTimeStatus {
  none,
  planned,
  confirmed,
}
```

意味:

```text
none
→ 時間指定なし

planned
→ 取得・予約予定、時刻未確定

confirmed
→ 時刻確定済み
```

既存フィールド:

```dart
preferredPerformanceTime
reservationTime
scheduledAccessTime
```

段階的な将来形:

```dart
class FixedSchedulePreference {
  final FixedTimeStatus status;
  final FixedScheduleType type;
  final String? selectedOptionId;
  final DateTime? startAt;
  final DateTime? endAt;
}
```

## 7. 公演回モデル

推奨:

```dart
class PerformanceTimeOption {
  final String id;
  final String facilityId;
  final DateTime date;
  final int performanceIndex;
  final String startTime;
}
```

表示:

```text
1回目 10:50
2回目 12:15
3回目 13:40
```

公演回未登録時:
- 選択不可
- 警告表示
- 仮時刻を作らない

## 8. スケジュール配置優先順位

```text
1. 入園・退園
2. 事前予約済みPS
3. 確定済みショー公演
4. 確定済みDPA / PP / SP / Entry
5. モバイルオーダー
6. 通常食事
7. 通常アトラクション
8. ショップ・サービス
```

固定予定は勝手に動かさない。
重複時は自動調整せず、競合警告を出す。

再生成時に維持:
- 完了済み
- 現在進行中
- 確定固定予定

再配置:
- 未実施通常予定
- 未確定取得予定
- 柔軟な食事

## 9. UI原則

- モバイル優先
- タグは原則`Wrap`
- 横選択肢にはScrollbar
- 横オーバーフローを許容しない
- カテゴリ・エリア色は`FacilityVisualStyle`
- 検索は部分一致・ひらがな・カタカナ・ローマ字対応

## 10. 永続化

- SharedPreferences
- JSON変換
- 新フィールドはデフォルト値を持つ
- 古い保存データを読み込める
- 旧データに時刻がある場合はconfirmed相当へ移行可能

## 11. 品質基準

```powershell
dart format <files>
flutter analyze
```

期待結果:

```text
No issues found!
```

追加確認:
- Windows実行
- モバイル幅
- 保存／再起動復元
- 固定予定競合
- 時刻未設定
- 旧データ移行
- 横オーバーフロー

## 12. 新チャット開始文

```text
Disney Planner開発の続きです。
添付したPROJECT_STATUS.md、ROADMAP.md、ARCHITECTURE.mdを読み、
現在の実装・設計・今後の計画を前提に進めてください。

コードは原則として省略なしの全文で、
設計凍結後に提示してください。
変更後はflutter analyzeでNo issues found!を目標にします。
```

コード生成前に必ず、対象ファイル・関連コンストラクタ・Controller API・AppState API・Domain Modelの整合性を確認する。
