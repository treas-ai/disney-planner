# Dynamic Wait-Time Scoring Integration

朝一は `通常時間帯代表待ち - 開園直後待ち` の節約分数を中心に評価します。通常時間帯はピークではなく中央値です。履歴Profileが無い場合は特定施設の人気待ち時間を固定値として捏造しません。休止・終了は評価前に除外し、DPA/PPは代替手段として減点、Happy Entryは節約がある場合のみ補正します。AIおまかせのアトラクション選択とScheduleEngineの朝一順位に同じ評価を接続します。
