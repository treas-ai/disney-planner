# AI Planner Phase 3 Implementation

実装日: 2026-08-18

## 目的

8/13の豪雨・長時間空白、8/12のDPA取得失敗やホテル休憩など、現地で予定が崩れた時の再計画判断をDomainへ追加する。

## 追加

- `RealtimeReplanningService`
  - 固定予定まで90分以上ある場合の中間プラン再生成提案
  - 雨・豪雨時の屋内候補優先（屋外Wishは削除しない）
  - 雨 + 疲労/荷物時のホテル休憩提案
  - DPA / Priority Pass が利用不可になった場合の代替案提案
  - Phase 2 の Route Pickup を固定予定前の残り時間に収まる場合だけ提案
- `ReplanningContext` / `ReplanningSuggestion`
- `FatigueLevel` / 再計画アクション・緊急度enum
- `ScheduleRecalculationRequest` に後方互換な任意の天候・パス・疲労・荷物・ホテル情報を追加
- `ScheduleRecalculationService` に再計画判定を接続
- Today再計算時に雨天設定とLive Pass状態を再計画へ引き渡す

## 安全方針

- 豪雨でも屋外Wishを自動削除しない。
- DPA/PP取得失敗時に通常待機へ勝手に切り替えない。
- ホテル休憩は候補として提示し、自動確定しない。
- Route Pickup は固定予定前15分の安全バッファを残して入る候補だけ提示する。
- 既存のSchedule Engine/保存データ形式を大規模変更しない。

## 回帰テスト

`test/ai_planner_phase3_test.dart`

- 10:15 → 14:00固定予定の長時間空白
- 豪雨 + 疲労 + 荷物でホテル休憩候補
- 豪雨でも屋外Wishを削除しない
- DPA利用不可時の代替案
- 固定予定に間に合うRoute Pickupのみ候補化
