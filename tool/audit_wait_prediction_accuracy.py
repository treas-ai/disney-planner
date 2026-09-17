#!/usr/bin/env python3
"""Backtest Disney Planner wait-profile prediction accuracy without data leakage.

The collector can poll the same facility many times per day. To avoid giving
high-frequency polling extra weight, observations are collapsed to one median
per facility/local-day/time-band. For each target day the predictor uses only
older matching weekdays, mirroring HistoricalWaitProfileGenerator's latest
four weekday medians (50/25/15/10). The target day's median is never used to
predict itself.
"""
from __future__ import annotations

import argparse
import csv
import gzip
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from statistics import median

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_ROOT = ROOT / "tool" / "wait_data"
DEFAULT_REPORT = ROOT / "docs" / "current" / "WAIT_PREDICTION_ACCURACY_AUDIT.md"
JST = timezone(timedelta(hours=9))
WEIGHTS = (0.50, 0.25, 0.15, 0.10)
BANDS = (
    ("afterOpening", "開園直後", 0, 660),
    ("beforeLunch", "昼前", 660, 720),
    ("afterLunch", "昼過ぎ", 720, 900),
    ("aroundShows", "ショー前後", 900, 1020),
    ("beforeDinner", "夕食前", 1020, 1080),
    ("afterDinner", "夕食後", 1080, 1200),
    ("beforeClosing", "閉園前", 1200, 24 * 60),
)
BAND_LABEL = {key: label for key, label, _, _ in BANDS}


@dataclass(frozen=True)
class DailyMedian:
    park_id: str
    facility_id: str
    local_date: str
    weekday: int
    band: str
    minutes: int


@dataclass(frozen=True)
class BacktestRow:
    park_id: str
    facility_id: str
    local_date: str
    band: str
    actual: int
    predicted: int
    error: int
    training_days: int


def ceil5(value: float) -> int:
    return max(0, int(math.ceil(value / 5.0) * 5))


def band_for(dt: datetime) -> str:
    local = dt.astimezone(JST) if dt.tzinfo else dt.replace(tzinfo=JST)
    minute = local.hour * 60 + local.minute
    for key, _, start, end in BANDS:
        if start <= minute < end:
            return key
    return "beforeClosing"


def iter_history_files(data_root: Path, park_id: str):
    live = data_root / "github_history"
    if live.exists():
        yield from sorted(live.rglob(f"*_{park_id}.csv"))
    archive = data_root / "archive" / "github_history"
    if archive.exists():
        yield from sorted(archive.rglob(f"*_{park_id}_waits.csv.gz"))


def read_observations(data_root: Path, park_id: str):
    for path in iter_history_files(data_root, park_id):
        opener = gzip.open if path.suffix == ".gz" else open
        try:
            with opener(path, "rt", encoding="utf-8", newline="") as handle:
                for row in csv.DictReader(handle):
                    facility_id = (row.get("facilityId") or "").strip()
                    observed = (row.get("observedAt") or "").strip()
                    raw_wait = (row.get("waitMinutes") or "").strip()
                    if not facility_id or not observed or not raw_wait:
                        continue
                    try:
                        wait = int(float(raw_wait))
                        dt = datetime.fromisoformat(observed.replace("Z", "+00:00"))
                    except ValueError:
                        continue
                    if wait < 0:
                        continue
                    local = dt.astimezone(JST) if dt.tzinfo else dt.replace(tzinfo=JST)
                    yield facility_id, local, band_for(dt), wait
        except (OSError, EOFError):
            continue


def daily_medians(data_root: Path, park_id: str) -> list[DailyMedian]:
    grouped: dict[tuple[str, str, str], list[int]] = defaultdict(list)
    weekdays: dict[tuple[str, str, str], int] = {}
    for facility_id, local, band, wait in read_observations(data_root, park_id):
        day = local.date().isoformat()
        key = (facility_id, day, band)
        grouped[key].append(wait)
        weekdays[key] = local.weekday()  # Monday=0; equality is all we need.
    result = []
    for (facility_id, day, band), values in grouped.items():
        result.append(DailyMedian(park_id, facility_id, day, weekdays[(facility_id, day, band)], band, int(median(values))))
    return sorted(result, key=lambda x: (x.facility_id, x.band, x.local_date))


def backtest(rows: list[DailyMedian], min_training_days: int) -> list[BacktestRow]:
    by_key: dict[tuple[str, str], list[DailyMedian]] = defaultdict(list)
    for row in rows:
        by_key[(row.facility_id, row.band)].append(row)
    output: list[BacktestRow] = []
    for (_, _), series in by_key.items():
        series.sort(key=lambda x: x.local_date)
        for target in series:
            prior = [r for r in series if r.local_date < target.local_date and r.weekday == target.weekday]
            latest = list(reversed(prior[-4:]))
            if len(latest) < min_training_days:
                continue
            weights = WEIGHTS[: len(latest)]
            predicted = ceil5(sum(r.minutes * w for r, w in zip(latest, weights)) / sum(weights))
            output.append(BacktestRow(target.park_id, target.facility_id, target.local_date, target.band, target.minutes, predicted, predicted - target.minutes, len(latest)))
    return output


def metrics(rows: list[BacktestRow]) -> tuple[int, float, float, float]:
    if not rows:
        return 0, 0.0, 0.0, 0.0
    abs_errors = [abs(r.error) for r in rows]
    errors = [r.error for r in rows]
    sq_errors = [r.error * r.error for r in rows]
    return len(rows), sum(abs_errors) / len(rows), sum(errors) / len(rows), math.sqrt(sum(sq_errors) / len(rows))


def render(data_root: Path, parks: list[str], min_training_days: int) -> str:
    all_daily: list[DailyMedian] = []
    all_tests: list[BacktestRow] = []
    per_park_daily: dict[str, list[DailyMedian]] = {}
    per_park_tests: dict[str, list[BacktestRow]] = {}
    for park in parks:
        daily = daily_medians(data_root, park)
        tests = backtest(daily, min_training_days)
        per_park_daily[park] = daily
        per_park_tests[park] = tests
        all_daily += daily
        all_tests += tests

    n, mae, bias, rmse = metrics(all_tests)
    lines = [
        "# Wait Prediction Accuracy Audit",
        "",
        f"Generated: {datetime.now(JST).isoformat(timespec='seconds')}",
        "",
        "## Method",
        "",
        "- Raw polling is collapsed to one median per facility / local day / time band.",
        "- Each target day is predicted from older occurrences of the same weekday only.",
        "- The latest four matching weekdays use weights 50% / 25% / 15% / 10%, matching HistoricalWaitProfileGenerator.",
        "- Predictions are rounded up to 5 minutes, matching planning behavior.",
        "- The target day is excluded from training, preventing look-ahead leakage.",
        f"- At least {min_training_days} older matching weekday(s) are required for a scored sample.",
        "",
        "## Overall",
        "",
    ]
    if n:
        lines += [f"- Scored samples: {n}", f"- MAE: {mae:.1f} min", f"- Bias (predicted - actual): {bias:+.1f} min", f"- RMSE: {rmse:.1f} min"]
    else:
        lines += ["- Scored samples: 0", "- Accuracy cannot be measured from the currently available local history.", "- Keep collecting history; this audit will become valid automatically once prior matching weekdays exist."]

    for park in parks:
        daily = per_park_daily[park]
        tests = per_park_tests[park]
        pn, pmae, pbias, prmse = metrics(tests)
        dates = sorted({r.local_date for r in daily})
        lines += ["", f"## {park}", "", f"- Local days present: {len(dates)}" + (f" ({dates[0]} to {dates[-1]})" if dates else ""), f"- Daily facility-band medians: {len(daily)}", f"- Scored samples: {pn}"]
        if pn:
            lines += [f"- MAE: {pmae:.1f} min", f"- Bias: {pbias:+.1f} min", f"- RMSE: {prmse:.1f} min"]
            by_facility: dict[str, list[BacktestRow]] = defaultdict(list)
            for row in tests:
                by_facility[row.facility_id].append(row)
            ranked = sorted(by_facility.items(), key=lambda item: metrics(item[1])[1], reverse=True)
            lines += ["", "### Highest-error facilities", "", "| Facility ID | N | MAE | Bias |", "|---|---:|---:|---:|"]
            for facility_id, facility_rows in ranked[:15]:
                fn, fmae, fbias, _ = metrics(facility_rows)
                lines.append(f"| `{facility_id}` | {fn} | {fmae:.1f} | {fbias:+.1f} |")
            by_band: dict[str, list[BacktestRow]] = defaultdict(list)
            for row in tests:
                by_band[row.band].append(row)
            lines += ["", "### Time-band accuracy", "", "| Band | N | MAE | Bias |", "|---|---:|---:|---:|"]
            for key, label, _, _ in BANDS:
                band_rows = by_band.get(key, [])
                bn, bmae, bbias, _ = metrics(band_rows)
                lines.append(f"| {label} | {bn} | {bmae:.1f} | {bbias:+.1f} |")

    lines += ["", "## Interpretation", "", "MAE measures typical absolute miss size. Bias above zero means the predictor tends to be conservative (high); below zero means it tends to underpredict. Do not feed these metrics back into scheduling automatically until sample counts are sufficient and stable.", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", type=Path, default=DEFAULT_DATA_ROOT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--park", action="append", dest="parks")
    parser.add_argument("--min-training-days", type=int, default=2)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    parks = args.parks or ["tokyo_disneyland", "tokyo_disneysea"]
    text = render(args.data_root, parks, max(1, min(4, args.min_training_days)))
    if args.check_only:
        print(text)
    else:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text, encoding="utf-8")
        print(f"Wrote {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
