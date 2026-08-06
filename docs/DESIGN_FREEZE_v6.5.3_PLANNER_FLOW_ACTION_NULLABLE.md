# DESIGN FREEZE v6.5.3

## 目的
無効化された下部CTAで`onPressed: null`を正しく扱う。

## 修正
- `_PlannerFlowAction.onPressed`を`VoidCallback?`へ変更。
- `_FlowShortcutButton`ではなく、実際のCTAモデルを修正する。
- CTAの文言・有効条件・遷移先は変更しない。

## 確認
```powershell
.\verify.ps1
.\dev.ps1
```
