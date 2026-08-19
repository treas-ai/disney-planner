#!/usr/bin/env python3
"""Compact the previous JST month's daily TDR history files.

Daily CSVs are useful while data is fresh. Once a month is complete, this script
merges each park/type into one gzip CSV and deletes the individual daily files.
That changes ~120 files/month (2 parks x 2 data types x ~30 days) into 4 files.
"""
from __future__ import annotations

import csv
import gzip
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JST = timezone(timedelta(hours=9))
SOURCES = (
    ("github_history", "waits"),
    ("dpa_history", "dpa"),
)
PARKS = ("tokyo_disneyland", "tokyo_disneysea")


def previous_month(now: datetime) -> tuple[int, int]:
    first = now.replace(day=1)
    prev = first - timedelta(days=1)
    return prev.year, prev.month


def compact_folder(folder: str, label: str, park: str, year: int, month: int) -> int:
    month_dir = ROOT / "tool/wait_data" / folder / f"{year:04d}" / f"{month:02d}"
    if not month_dir.exists():
        return 0

    files = sorted(month_dir.glob(f"{year:04d}-{month:02d}-??_{park}.csv"))
    if not files:
        return 0

    archive_dir = ROOT / "tool/wait_data" / "archive" / folder / f"{year:04d}"
    archive_dir.mkdir(parents=True, exist_ok=True)
    output = archive_dir / f"{year:04d}-{month:02d}_{park}_{label}.csv.gz"

    header = None
    rows = []
    seen = set()
    for path in files:
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            if header is None:
                header = reader.fieldnames
            for row in reader:
                key = tuple(row.get(k, "") for k in (header or []))
                if key not in seen:
                    seen.add(key)
                    rows.append(row)

    if not header:
        return 0

    with gzip.open(output, "wt", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)

    for path in files:
        path.unlink()

    try:
        month_dir.rmdir()
        month_dir.parent.rmdir()
    except OSError:
        pass

    print(f"{folder}/{park}: {len(files)} daily files -> {output.relative_to(ROOT)} ({len(rows)} rows)")
    return len(files)


def main() -> int:
    year, month = previous_month(datetime.now(JST))
    removed = 0
    for folder, label in SOURCES:
        for park in PARKS:
            removed += compact_folder(folder, label, park, year, month)
    print(f"Compaction complete: replaced {removed} daily files with monthly archives.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
