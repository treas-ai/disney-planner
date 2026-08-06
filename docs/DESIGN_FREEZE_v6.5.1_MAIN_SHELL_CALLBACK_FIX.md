# DESIGN FREEZE v6.5.1

## 目的
v6.5.0で発生した`missing_required_argument`を修正する。

## 凍結仕様
- `WishListScreen.onFlowContinueAvailabilityChanged`を`MainShell`から必ず渡す。
- AI質問中は下部CTAを無効化する。
- 質問完了後または一覧選択時だけ候補確認へ進める。
- 候補確認画面の表示・候補生成ロジックは変更しない。

## 確認
```powershell
.\verify.ps1
.\dev.ps1
```
