# DESIGN FREEZE v6.5.5

## 目的
v6.5.4で失われたWish ListとMainShellのCTA状態連携を復元する。

## 凍結仕様
- `onFlowContinueAvailabilityChanged`を必須引数として復元する。
- 質問完了、一覧表示、リセット時にCTA状態を同期する。
- v6.5.4のPC表示改善は変更しない。
- 候補生成ロジックは変更しない。

## 確認
```powershell
.\verify.ps1
.\dev.ps1
```
