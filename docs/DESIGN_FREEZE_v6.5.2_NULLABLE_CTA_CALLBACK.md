# DESIGN FREEZE v6.5.2

## 目的
無効CTAへ`onPressed: null`を渡せる型定義へ修正する。

## 変更
- `_PlannerFlowAction.onPressed`を`VoidCallback?`へ変更。
- `FilledButton.icon`はnullコールバックを無効状態として扱う。
- CTAの表示文言・遷移条件・候補生成ロジックは変更しない。

## 確認
```powershell
.\verify.ps1
.\dev.ps1
```
