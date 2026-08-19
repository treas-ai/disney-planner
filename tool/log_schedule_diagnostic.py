#!/usr/bin/env python3
"""Record GitHub Actions schedule timing for the TDR collector.

This does not claim to know GitHub's internal queued timestamp. Instead it records
the actual workflow execution time and compares consecutive scheduled runs against
the intended 5-minute cadence. Missing 5-minute slots are therefore estimated from
the observed gap between scheduled workflow runs.
"""
from __future__ import annotations

import csv
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tool" / "wait_data" / "schedule_diagnostics.csv"
JST = timezone(timedelta(hours=9))

HEADER = [
    "runId",
    "eventName",
    "cron",
    "recordedAtUtc",
    "recordedAtJst",
    "nearestFiveMinuteSlotJst",
    "secondsAfterNearestSlot",
    "minutesSincePreviousScheduledRun",
    "estimatedMissingFiveMinuteSlots",
]


def read_event_schedule() -> str:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path:
        return ""
    try:
        payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    return str(payload.get("schedule") or "")


def nearest_five_minute_slot(now_jst: datetime) -> datetime:
    minute = (now_jst.minute // 5) * 5
    return now_jst.replace(minute=minute, second=0, microsecond=0)


def read_previous_scheduled_time() -> datetime | None:
    if not OUT.exists():
        return None
    try:
        with OUT.open("r", encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except OSError:
        return None

    for row in reversed(rows):
        if row.get("eventName") != "schedule":
            continue
        value = row.get("recordedAtJst", "")
        try:
            return datetime.fromisoformat(value)
        except ValueError:
            continue
    return None


def main() -> int:
    now_utc = datetime.now(timezone.utc)
    now_jst = now_utc.astimezone(JST)
    slot = nearest_five_minute_slot(now_jst)

    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    previous = read_previous_scheduled_time() if event_name == "schedule" else None

    gap_minutes = ""
    missing_slots = ""
    if previous is not None:
        seconds = max(0.0, (now_jst - previous).total_seconds())
        gap = seconds / 60.0
        gap_minutes = f"{gap:.2f}"
        # One current run occupies one cadence slot. Every additional full
        # 5-minute interval between runs is treated as an estimated missed slot.
        missing_slots = str(max(0, round(gap / 5) - 1))

    row = {
        "runId": os.environ.get("GITHUB_RUN_ID", ""),
        "eventName": event_name,
        "cron": read_event_schedule(),
        "recordedAtUtc": now_utc.isoformat(timespec="seconds"),
        "recordedAtJst": now_jst.isoformat(timespec="seconds"),
        "nearestFiveMinuteSlotJst": slot.isoformat(timespec="seconds"),
        "secondsAfterNearestSlot": str(int((now_jst - slot).total_seconds())),
        "minutesSincePreviousScheduledRun": gap_minutes,
        "estimatedMissingFiveMinuteSlots": missing_slots,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    new_file = not OUT.exists()
    with OUT.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=HEADER)
        if new_file:
            writer.writeheader()
        writer.writerow(row)

    print("Schedule diagnostic")
    print(f"  event: {event_name}")
    print(f"  cron: {row['cron'] or '(manual/unknown)'}")
    print(f"  actual JST: {row['recordedAtJst']}")
    print(f"  nearest 5-min slot: {row['nearestFiveMinuteSlotJst']}")
    print(f"  seconds after slot: {row['secondsAfterNearestSlot']}")
    if gap_minutes:
        print(f"  minutes since previous scheduled run: {gap_minutes}")
        print(f"  estimated missing 5-min slots: {missing_slots}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
