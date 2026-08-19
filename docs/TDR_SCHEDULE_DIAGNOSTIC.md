# TDR GitHub schedule diagnostic

This patch adds a small diagnostic recorder to the existing TDR collector.

It records:
- actual execution time (UTC/JST)
- cron expression that triggered the run
- nearest 5-minute JST slot
- seconds after that slot
- minutes since the previous scheduled run
- estimated number of missing 5-minute slots

Output:
`tool/wait_data/schedule_diagnostics.csv`

Important:
GitHub does not expose the scheduler's private queued-at timestamp to this script,
so `estimatedMissingFiveMinuteSlots` is inferred from the gap between actual
scheduled workflow runs. This is intended to distinguish "roughly every 5 minutes"
from "roughly hourly / heavily dropped".
