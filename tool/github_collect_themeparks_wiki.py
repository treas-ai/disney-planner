#!/usr/bin/env python3
"""Lightweight GitHub Actions collector for Tokyo Disney Resort live data.

Uses only the Python standard library so frequent scheduled runs do not need
Flutter/Dart setup. Data is stored by JST calendar day to keep Git diffs small.
"""
from __future__ import annotations

import csv
import json
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "assets/master/live_mapping/themeparks_wiki_tokyo.json"
DATA_ROOT = ROOT / "tool/wait_data/github_history"
DPA_ROOT = ROOT / "tool/wait_data/dpa_history"
UNMATCHED_ROOT = ROOT / "tool/wait_data/unmatched"
JST = timezone(timedelta(hours=9))
USER_AGENT = "DisneyPlanner/1.0 GitHub wait-history collector"

WAIT_HEADER = ["parkId", "facilityId", "observedAt", "waitMinutes", "status", "sourceEntityId"]
DPA_HEADER = ["parkId", "sourceEntityId", "facilityId", "name", "entityType", "observedAt", "status", "state", "returnStart", "returnEnd"]


def normalize(value: str) -> str:
    value = value.lower().replace("&", "and")
    return re.sub(r"[^a-z0-9]", "", value)


def fetch_json(entity_id: str) -> dict:
    url = f"https://api.themeparks.wiki/v1/entity/{entity_id}/live"
    request = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}: {url}")
        return json.load(response)


def daily_path(base: Path, park_id: str, now_jst: datetime) -> Path:
    return base / f"{now_jst:%Y}" / f"{now_jst:%m}" / f"{now_jst:%Y-%m-%d}_{park_id}.csv"


def read_keys(path: Path, fields: tuple[str, ...]) -> set[tuple[str, ...]]:
    if not path.exists():
        return set()
    with path.open("r", encoding="utf-8", newline="") as handle:
        return {tuple(row.get(field, "") for field in fields) for row in csv.DictReader(handle)}


def append_rows(path: Path, header: list[str], rows: list[dict[str, object]]) -> int:
    if not rows:
        return 0
    path.parent.mkdir(parents=True, exist_ok=True)
    new_file = not path.exists()
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, extrasaction="ignore")
        if new_file:
            writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def collect_park(park_id: str, park: dict, now_jst: datetime) -> tuple[int, int, int]:
    aliases = {normalize(k): str(v) for k, v in (park.get("aliases") or {}).items()}
    payload = fetch_json(str(park["entityId"]))
    entries = payload.get("liveData") or []

    wait_path = daily_path(DATA_ROOT, park_id, now_jst)
    dpa_path = daily_path(DPA_ROOT, park_id, now_jst)
    wait_keys = read_keys(wait_path, ("facilityId", "observedAt"))
    dpa_keys = read_keys(dpa_path, ("sourceEntityId", "observedAt", "state", "returnStart", "returnEnd"))

    waits: list[dict[str, object]] = []
    dpas: list[dict[str, object]] = []
    unmatched: set[str] = set()

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        name = str(entry.get("name") or "")
        source_id = str(entry.get("id") or entry.get("entityId") or "")
        entity_type = str(entry.get("entityType") or "")
        status = str(entry.get("status") or "")
        observed = str(entry.get("lastUpdated") or datetime.now(timezone.utc).isoformat())
        queue = entry.get("queue") if isinstance(entry.get("queue"), dict) else {}
        local_id = aliases.get(normalize(name), "")

        standby = queue.get("STANDBY") if isinstance(queue.get("STANDBY"), dict) else None
        if entity_type.upper() == "ATTRACTION" and standby is not None:
            wait = standby.get("waitTime")
            if isinstance(wait, (int, float)) and wait >= 0:
                if local_id:
                    key = (local_id, observed)
                    if key not in wait_keys:
                        wait_keys.add(key)
                        waits.append({
                            "parkId": park_id,
                            "facilityId": local_id,
                            "observedAt": observed,
                            "waitMinutes": round(wait),
                            "status": status,
                            "sourceEntityId": source_id,
                        })
                else:
                    unmatched.add(f"{name}\t{source_id}")

        paid = queue.get("PAID_RETURN_TIME") if isinstance(queue.get("PAID_RETURN_TIME"), dict) else None
        if paid is not None:
            state = str(paid.get("state") or "")
            return_start = str(paid.get("returnStart") or "")
            return_end = str(paid.get("returnEnd") or "")
            key = (source_id, observed, state, return_start, return_end)
            if key not in dpa_keys:
                dpa_keys.add(key)
                dpas.append({
                    "parkId": park_id,
                    "sourceEntityId": source_id,
                    "facilityId": local_id,
                    "name": name,
                    "entityType": entity_type,
                    "observedAt": observed,
                    "status": status,
                    "state": state,
                    "returnStart": return_start,
                    "returnEnd": return_end,
                })

    wait_count = append_rows(wait_path, WAIT_HEADER, waits)
    dpa_count = append_rows(dpa_path, DPA_HEADER, dpas)

    unmatched_path = UNMATCHED_ROOT / f"{park_id}.txt"
    if unmatched:
        unmatched_path.parent.mkdir(parents=True, exist_ok=True)
        existing = set(unmatched_path.read_text(encoding="utf-8").splitlines()) if unmatched_path.exists() else set()
        unmatched_path.write_text("\n".join(sorted(existing | unmatched)) + "\n", encoding="utf-8")

    return wait_count, dpa_count, len(unmatched)


def main() -> int:
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    now_jst = datetime.now(JST)
    total_waits = total_dpa = total_unmatched = 0
    for park_id in ("tokyo_disneyland", "tokyo_disneysea"):
        try:
            waits, dpa, unmatched = collect_park(park_id, config[park_id], now_jst)
        except (urllib.error.URLError, TimeoutError, RuntimeError, KeyError, json.JSONDecodeError) as exc:
            print(f"{park_id}: collection failed: {exc}", file=sys.stderr)
            continue
        total_waits += waits
        total_dpa += dpa
        total_unmatched += unmatched
        print(f"{park_id}: +{waits} waits, +{dpa} DPA states, {unmatched} unmatched")
    print(f"total: +{total_waits} waits, +{total_dpa} DPA states")
    return 0 if (total_waits + total_dpa) > 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
