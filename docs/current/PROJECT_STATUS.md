# PROJECT STATUS

## Current focus

Data-driven Schedule Optimization。
希望退園時刻を完全なハード制約から、価値評価可能なソフト制約へ段階的に移行中。

## Confirmed baseline before this Step

直近ユーザー確認:
- `flutter analyze`: No issues found
- `flutter test`: 104 tests passed

## Step 1 implementation

- `DesiredExitTimeEvaluator` を追加
- overtime minutes を連続的なコストとして評価
- experience value / opportunity value / user preference value / downstream impact を分相当で比較可能
- 正味価値が正の場合だけ希望退園超過を採用
- 公式公演候補へ最初に統合
- 採用時は退園ScheduleItemを実効退園時刻まで延長し、希望退園時刻をnoteへ残す
- 個別公演名のハードコードなし

## Frozen direction

- 価値を低・中・高で判定しない
- 固定30分待ち等を主判断にしない
- 収集済み待ち時間データを利用する
- 移動時間を正式なコストとして扱う
- 待ち時間だけを最小化してパークを往復しない
- DPA価値を実時間節約で評価する
- 固定予定はハード制約として守る
- 希望退園時刻は無条件延長せず、価値対超過コストで判断する

## Next implementation target

まず `verify.ps1` とAI評価用プランでStep 1を検証する。
成功後、下流予定への影響コストと、公式公演以外へ適用する範囲をStep 2として検討する。
